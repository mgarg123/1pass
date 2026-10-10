import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_service.dart';

class UpdateDialog extends StatefulWidget {
  final GitHubRelease release;

  const UpdateDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, GitHubRelease release) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(release: release),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isAlreadyDownloaded = false;
  bool _isCheckingCache = true;
  double _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  int _downloadedFileSize = 0;
  String _statusMessage = '';
  String _currentVersion = '';
  String? _localSavePath;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _initVersionAndCache();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog closed');
    super.dispose();
  }

  Future<void> _initVersionAndCache() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final clean = info.version.split('+')[0];
      if (mounted) {
        setState(() {
          _currentVersion = clean;
        });
      }
    } catch (_) {}

    await _checkDownloadedCache();
  }

  Future<void> _checkDownloadedCache() async {
    try {
      final updateService = UpdateService();
      final asset = updateService.getAssetForPlatform(widget.release);
      final downloadUrl = asset?.browserDownloadUrl;

      if (downloadUrl == null) {
        if (mounted) setState(() => _isCheckingCache = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = Uri.parse(downloadUrl).pathSegments.last;
      final savePath = '${tempDir.path}/$fileName';
      final file = File(savePath);

      if (await file.exists()) {
        final length = await file.length();
        // Verify file is complete: matches asset size if known, or is > 1MB
        final isComplete = (asset != null && asset.size > 0)
            ? (length == asset.size)
            : (length > 1024 * 1024);

        if (isComplete) {
          if (mounted) {
            setState(() {
              _isAlreadyDownloaded = true;
              _localSavePath = savePath;
              _downloadedFileSize = length;
              _isCheckingCache = false;
            });
          }
          return;
        } else {
          // Incomplete or stale file, clean it up
          await file.delete();
        }
      }

      if (mounted) {
        setState(() {
          _isAlreadyDownloaded = false;
          _localSavePath = savePath;
          _isCheckingCache = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingCache = false);
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isAlreadyDownloaded && _localSavePath != null) {
      await _openInstaller(_localSavePath!);
      return;
    }
    await _startDownload();
  }

  Future<void> _startDownload({bool forceFresh = false}) async {
    if (Platform.isIOS) {
      final url = Uri.parse(widget.release.htmlUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    final updateService = UpdateService();
    final asset = updateService.getAssetForPlatform(widget.release);
    final downloadUrl = asset?.browserDownloadUrl;

    if (downloadUrl == null) {
      final url = Uri.parse(widget.release.htmlUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = Uri.parse(downloadUrl).pathSegments.last;
    final finalPath = '${tempDir.path}/$fileName';
    final partPath = '${tempDir.path}/$fileName.part';

    // Double check cache before downloading if not forced
    final existingFile = File(finalPath);
    if (!forceFresh && await existingFile.exists()) {
      final len = await existingFile.length();
      if ((asset != null && asset.size > 0 && len == asset.size) || len > 1024 * 1024) {
        setState(() {
          _isAlreadyDownloaded = true;
          _localSavePath = finalPath;
          _downloadedFileSize = len;
        });
        await _openInstaller(finalPath);
        return;
      }
    }

    _cancelToken = CancelToken();

    setState(() {
      _isDownloading = true;
      _isAlreadyDownloaded = false;
      _progress = 0;
      _receivedBytes = 0;
      _totalBytes = (asset != null && asset.size > 0) ? asset.size : 0;
      _statusMessage = 'Starting download...';
    });

    try {
      final partFile = File(partPath);
      if (await partFile.exists()) {
        await partFile.delete();
      }

      final dio = Dio();
      await dio.download(
        downloadUrl,
        partPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              final effectiveTotal = total > 0 ? total : (_totalBytes > 0 ? _totalBytes : 0);
              _totalBytes = effectiveTotal;
              _progress = effectiveTotal > 0 ? (received / effectiveTotal).clamp(0.0, 1.0) : 0.0;
              _statusMessage = 'Downloading package...';
            });
          }
        },
      );

      // Download finished: rename .part to final file atomically
      final downloadedPart = File(partPath);
      if (await downloadedPart.exists()) {
        if (await existingFile.exists()) {
          await existingFile.delete();
        }
        await downloadedPart.rename(finalPath);

        final finalLen = await File(finalPath).length();
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isAlreadyDownloaded = true;
            _localSavePath = finalPath;
            _downloadedFileSize = finalLen;
            _statusMessage = 'Download complete. Launching installer...';
          });
          await _openInstaller(finalPath);
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = 'Download paused';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = 'Download failed. Check connection & try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download error occurred. Please try again.';
        });
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    setState(() {
      _isDownloading = false;
      _statusMessage = 'Download cancelled';
    });
  }

  Future<void> _openInstaller(String path) async {
    setState(() {
      _statusMessage = 'Launching installer...';
    });
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _statusMessage = 'Could not auto-open: ${result.message}';
          _isDownloading = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to launch installer.';
          _isDownloading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final updateService = UpdateService();
    final asset = updateService.getAssetForPlatform(widget.release);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Row ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withValues(alpha: 0.25), primaryColor.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A newer version of 1Pass is ready',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Version Comparison Pill ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  if (_currentVersion.isNotEmpty) ...[
                    Text(
                      'v$_currentVersion',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.release.displayTag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (asset != null && asset.size > 0)
                    Text(
                      _formatBytes(asset.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),

            // ── Release Notes / Changelog ──
            if (widget.release.body.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 130),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text(
                          "What's New",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          widget.release.body.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // ── Download Progress / Cache Status Area ──
            if (_isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _totalBytes > 0
                              ? '${_formatBytes(_receivedBytes)} of ${_formatBytes(_totalBytes)}'
                              : _formatBytes(_receivedBytes),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _totalBytes > 0 ? _progress : null,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(primaryColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelDownload,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_isAlreadyDownloaded) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Package Already Downloaded',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF34C759),
                            ),
                          ),
                          Text(
                            'Ready to install immediately (${_formatBytes(_downloadedFileSize)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _startDownload(forceFresh: true),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'Redownload',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusMessage.contains('failed') || _statusMessage.contains('error')
                        ? Colors.redAccent
                        : Colors.white60,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // ── Buttons ──
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isDownloading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isDownloading || _isCheckingCache) ? null : _handlePrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCheckingCache
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAlreadyDownloaded
                                    ? Icons.install_mobile_rounded
                                    : Icons.download_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isAlreadyDownloaded ? 'Install Now' : 'Download & Install',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
