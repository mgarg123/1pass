import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';

class RecoveryKeyModal extends ConsumerStatefulWidget {
  final String recoveryKey;
  final bool isDismissible;

  const RecoveryKeyModal({
    super.key,
    required this.recoveryKey,
    this.isDismissible = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String recoveryKey,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => RecoveryKeyModal(
        recoveryKey: recoveryKey,
        isDismissible: isDismissible,
      ),
    );
  }

  @override
  ConsumerState<RecoveryKeyModal> createState() => _RecoveryKeyModalState();
}

class _RecoveryKeyModalState extends ConsumerState<RecoveryKeyModal> {
  bool _hasSaved = false;

  String _getEmergencyKitText() {
    return '''
========================================
1PASS EMERGENCY RECOVERY KIT
========================================
Generated: ${DateTime.now().toLocal().toString().split('.')[0]}

EMERGENCY RECOVERY KEY:
${widget.recoveryKey}

IMPORTANT INSTRUCTIONS:
1. Keep this document in a safe and private location (e.g. print it or store on an encrypted USB drive).
2. If you ever forget your 1Pass Master Password, this key or file is the ONLY way to regain access to your vault.
3. You can restore your vault by entering this key or uploading this file on the Recovery screen.
4. 1Pass uses Zero-Knowledge end-to-end encryption. No one (not even customer support) can recover your account without this key.
========================================
''';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.recoveryKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency Recovery Key copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() => _hasSaved = true);
  }

  Future<void> _downloadEmergencyKit() async {
    final text = _getEmergencyKitText();
    final bytes = Uint8List.fromList(utf8.encode(text));
    final filename = '1Pass-Emergency-Kit-${DateTime.now().toIso8601String().split('T')[0]}.txt';

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Emergency Recovery Kit',
        fileName: filename,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved Emergency Kit to $outputFile')),
          );
        }
        setState(() => _hasSaved = true);
        return;
      }
    } catch (_) {}

    // Fallback: Share as a file (.txt attachment) so user can save to Files / Downloads / Drive
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: filename,
              mimeType: 'text/plain',
            ),
          ],
          subject: '1Pass Emergency Recovery Key',
        ),
      );
      setState(() => _hasSaved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    }
  }

  Future<void> _shareEmergencyKit() async {
    final text = _getEmergencyKitText();
    final bytes = Uint8List.fromList(utf8.encode(text));
    final filename = '1Pass-Emergency-Kit-${DateTime.now().toIso8601String().split('T')[0]}.txt';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: 'text/plain',
          ),
        ],
        text: text,
        subject: '1Pass Emergency Recovery Key',
      ),
    );
    setState(() => _hasSaved = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: widget.isDismissible || _hasSaved,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFF222222)),
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.vpn_key_rounded, color: primaryColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Recovery Key',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zero-Knowledge Backup',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1315),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Save this key or file now. If you ever forget your Master Password, this is the ONLY way to recover your vault.',
                      style: TextStyle(color: Colors.red[200], fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: SelectableText(
                widget.recoveryKey,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333333)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadEmergencyKit,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save File'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333333)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareEmergencyKit,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333333)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: primaryColor,
              title: const Text(
                'I have saved my Emergency Recovery Key in a safe place.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              value: _hasSaved,
              onChanged: (val) {
                setState(() => _hasSaved = val ?? false);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _hasSaved
                  ? () {
                      ref.read(authProvider.notifier).clearNewlyGeneratedRecoveryKey();
                      Navigator.of(context).pop();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: const Text('Done & Continue to Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
