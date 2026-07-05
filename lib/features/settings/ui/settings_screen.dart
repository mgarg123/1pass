import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auto_lock_provider.dart';
import '../providers/backup_provider.dart';
import '../../auth/providers/biometric_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'change_master_password_screen.dart';
import 'import_backup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLockSeconds = ref.watch(autoLockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Auto-lock Timer'),
            subtitle: const Text('Require master password after inactivity'),
            trailing: DropdownButton<int>(
              value: autoLockSeconds,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 seconds')),
                DropdownMenuItem(value: 60, child: Text('1 minute')),
                DropdownMenuItem(value: 120, child: Text('2 minutes')),
                DropdownMenuItem(value: 300, child: Text('5 minutes')),
                DropdownMenuItem(value: 0, child: Text('Never (Not Recommended)', style: TextStyle(color: Colors.redAccent))),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(autoLockProvider.notifier).setTimer(val);
                }
              },
            ),
          ),
          const Divider(),
          if (ref.watch(biometricProvider).isSupported)
            SwitchListTile(
              title: const Text('Enable Biometric Unlock'),
              subtitle: const Text('Use fingerprint/face to unlock (requires master password every 7 days)'),
              value: ref.watch(biometricProvider).isEnabled,
              onChanged: (val) async {
                try {
                  final currentKey = ref.read(authProvider).encryptionKey;
                  await ref.read(biometricProvider.notifier).setEnabled(val, currentKey);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          const Divider(),
          ListTile(
            title: const Text('Change Master Password'),
            subtitle: const Text('Update your master password and re-encrypt vault'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangeMasterPasswordScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Export Vault Backup'),
            subtitle: const Text('Save an encrypted copy of your vault'),
            trailing: const Icon(Icons.file_upload),
            onTap: () async {
              try {
                await ref.read(backupProvider).exportVault();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup exported successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Import Vault Backup'),
            subtitle: const Text('Merge an encrypted backup into your vault'),
            trailing: const Icon(Icons.file_download),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                withData: true,
              );
              
              if (result != null) {
                String? jsonString;
                
                if (result.files.single.bytes != null) {
                  jsonString = utf8.decode(result.files.single.bytes!);
                } else if (result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  jsonString = await file.readAsString();
                }

                if (jsonString != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ImportBackupScreen(backupJson: jsonString!)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
