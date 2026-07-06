import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auto_lock_provider.dart';
import '../providers/backup_provider.dart';
import '../../auth/providers/biometric_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/breach_settings_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Auto-lock Timer'),
                  subtitle: const Text('Require master password after inactivity'),
                  trailing: DropdownButton<int>(
                    value: autoLockSeconds,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 seconds')),
                      DropdownMenuItem(value: 60, child: Text('1 minute')),
                      DropdownMenuItem(value: 120, child: Text('2 minutes')),
                      DropdownMenuItem(value: 300, child: Text('5 minutes')),
                      DropdownMenuItem(value: 0, child: Text('Never', style: TextStyle(color: Colors.redAccent))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(autoLockProvider.notifier).setTimer(val);
                      }
                    },
                  ),
                ),
                if (ref.watch(biometricProvider).isSupported) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Enable Biometric Unlock'),
                    subtitle: const Text('Use fingerprint/face to unlock'),
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
                ],
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.security),
                  title: const Text('Check Password Breaches'),
                  subtitle: const Text('Anonymously check if passwords are in known breaches (HIBP)'),
                  value: ref.watch(breachSettingsProvider),
                  onChanged: (val) {
                    ref.read(breachSettingsProvider.notifier).setEnabled(val);
                  },
                ),
              ],
            ),
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change Master Password'),
                  subtitle: const Text('Update your master password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangeMasterPasswordScreen()),
                    );
                  },
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Export Vault Backup'),
                  subtitle: const Text('Save an encrypted copy of your vault'),
                  trailing: const Icon(Icons.chevron_right),
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Import Vault Backup'),
                  subtitle: const Text('Merge an encrypted backup into your vault'),
                  trailing: const Icon(Icons.chevron_right),
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
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Sign out of your cloud account'),
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}
