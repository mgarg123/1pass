import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';

class UpdateDialog extends StatefulWidget {
  final GitHubRelease release;

  const UpdateDialog({Key? key, required this.release}) : super(key: key);

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
  double _progress = 0;
  String _statusMessage = '';

  Future<void> _startUpdate() async {
    if (Platform.isIOS) {
      // iOS cannot install programmatically. Just open the release page.
      final url = Uri.parse(widget.release.htmlUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    final updateService = UpdateService();
    final downloadUrl = updateService.getDownloadUrlForPlatform(widget.release);

    if (downloadUrl == null) {
      // Fallback to browser if no asset found
      final url = Uri.parse(widget.release.htmlUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading update...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = Uri.parse(downloadUrl).pathSegments.last;
      final savePath = '${tempDir.path}/$fileName';

      if (File(savePath).existsSync()) {
        setState(() {
          _statusMessage = 'Update already downloaded. Opening installer...';
        });
      } else {
        final dio = Dio();
        await dio.download(
          downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _progress = received / total;
              });
            }
          },
        );

        setState(() {
          _statusMessage = 'Opening installer...';
        });
      }

      final result = await OpenFile.open(savePath);
      
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _statusMessage = 'Failed to open installer: ${result.message}';
          _isDownloading = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                const Text(
                  'Update Available',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Version ${widget.release.tagName} is available. We recommend updating to get the latest features and security improvements.',
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            if (widget.release.body.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 120,
                child: SingleChildScrollView(
                  child: Text(
                    widget.release.body,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress,
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update Now'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
