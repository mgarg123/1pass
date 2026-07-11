import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../providers/auto_lock_provider.dart';
import '../providers/backup_provider.dart';
import '../../auth/providers/biometric_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/breach_settings_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'change_master_password_screen.dart';
import 'import_backup_screen.dart';
import '../providers/health_settings_provider.dart';
import '../../vault/ui/password_health_screen.dart';
import '../../../core/config/storage_mode.dart';
import '../../../core/sync/sync_provider.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8, top: 24),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final List<Widget> children;
  const _SectionContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // iOS-like grouped dark background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: Colors.grey[850],
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLockSeconds = ref.watch(autoLockProvider);
    final biometricState = ref.watch(biometricProvider);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      backgroundColor: Colors.black, // True dark background
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Storage Mode Section ──
          const _SectionHeader('Storage Mode').animate().fadeIn(delay: 25.ms),
          _buildStorageModeSection(context, ref).animate().fadeIn(delay: 25.ms).slideY(begin: 0.05, end: 0),

          const _SectionHeader('Security & Authentication').animate().fadeIn(delay: 50.ms),
          _SectionContainer(
            children: [
              ListTile(
                leading: Icon(Icons.timer_outlined, color: Colors.grey[400]),
                title: const Text('Auto-lock Timer'),
                subtitle: const Text('Require master password after inactivity', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white54)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: autoLockSeconds,
                    icon: const Icon(Icons.expand_more, color: Colors.blueAccent),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 16),
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
              ),
              if (biometricState.isSupported) ...[
                const _CustomDivider(),
                SwitchListTile(
                  activeColor: Colors.blueAccent,
                  secondary: Icon(Icons.fingerprint, color: Colors.grey[400]),
                  title: const Text('Biometric Unlock'),
                  value: biometricState.isEnabled,
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
              if (isAndroid) ...[
                const _CustomDivider(),
                ListTile(
                  leading: Icon(Icons.keyboard_outlined, color: Colors.grey[400]),
                  title: const Text('Enable Autofill'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    if (!ref.read(biometricProvider).isEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enable Biometric Unlock first')),
                      );
                      return;
                    }
                    const channel = MethodChannel('com.example.onepass/autofill');
                    try {
                      await channel.invokeMethod('requestSetAutofillService');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to open Autofill settings: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ],
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, end: 0),

          const _SectionHeader('Security Tools').animate().fadeIn(delay: 100.ms),
          _SectionContainer(
            children: [
              ListTile(
                leading: Icon(Icons.health_and_safety, color: Colors.grey[400]),
                title: const Text('Password Health Dashboard'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasswordHealthScreen()),
                  );
                },
              ),
              const _CustomDivider(),
              SwitchListTile(
                activeColor: Colors.blueAccent,
                secondary: Icon(Icons.security, color: Colors.grey[400]),
                title: const Text('Check Password Breaches'),
                subtitle: const Text('Anonymously check against HIBP database', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white54)),
                value: ref.watch(breachSettingsProvider),
                onChanged: (val) {
                  ref.read(breachSettingsProvider.notifier).setEnabled(val);
                },
              ),
              const _CustomDivider(),
              SwitchListTile(
                activeColor: Colors.blueAccent,
                secondary: Icon(Icons.history_toggle_off, color: Colors.grey[400]),
                title: const Text('Flag Old Passwords'),
                subtitle: const Text('Warn about passwords older than 1 year', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white54)),
                value: ref.watch(flagOldPasswordsProvider),
                onChanged: (val) {
                  ref.read(flagOldPasswordsProvider.notifier).setEnabled(val);
                },
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

          const _SectionHeader('Account & Vault').animate().fadeIn(delay: 150.ms),
          _SectionContainer(
            children: [
              ListTile(
                leading: Icon(Icons.password, color: Colors.grey[400]),
                title: const Text('Change Master Password'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangeMasterPasswordScreen()),
                  );
                },
              ),
              const _CustomDivider(),
              ListTile(
                leading: Icon(Icons.file_upload_outlined, color: Colors.grey[400]),
                title: const Text('Export Vault Backup'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
              const _CustomDivider(),
              ListTile(
                leading: Icon(Icons.file_download_outlined, color: Colors.grey[400]),
                title: const Text('Import Vault Backup'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),
          
          const SizedBox(height: 24),
          _SectionContainer(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }

  Widget _buildStorageModeSection(BuildContext context, WidgetRef ref) {
    final modeConfig = ref.watch(storageModeProvider);
    final syncState = ref.watch(syncProvider);

    String modeLabel;
    IconData modeIcon;
    Color modeColor;

    switch (modeConfig?.mode) {
      case StorageMode.localOnly:
        modeLabel = 'Local Only';
        modeIcon = Icons.smartphone;
        modeColor = const Color(0xFF10B981);
        break;
      case StorageMode.cloudSync:
        modeLabel = 'Cloud Sync';
        modeIcon = Icons.cloud_sync;
        modeColor = const Color(0xFF8B5CF6);
        break;
      case StorageMode.byodSync:
        modeLabel = 'Bring Your Own DB';
        modeIcon = Icons.dns_outlined;
        modeColor = const Color(0xFFF59E0B);
        break;
      default:
        modeLabel = 'Not configured';
        modeIcon = Icons.help_outline;
        modeColor = Colors.grey;
    }

    String syncLabel;
    Color syncColor;
    switch (syncState) {
      case SyncState.synced:
        syncLabel = 'Synced';
        syncColor = const Color(0xFF10B981);
        break;
      case SyncState.syncing:
        syncLabel = 'Syncing...';
        syncColor = const Color(0xFF8B5CF6);
        break;
      case SyncState.offline:
        syncLabel = 'Offline';
        syncColor = Colors.orangeAccent;
        break;
      case SyncState.failed:
        syncLabel = 'Sync failed';
        syncColor = Colors.redAccent;
        break;
      case SyncState.disabled:
        syncLabel = 'No sync';
        syncColor = Colors.white38;
        break;
    }

    return _SectionContainer(
      children: [
        ListTile(
          leading: Icon(modeIcon, color: modeColor),
          title: Text(modeLabel),
          subtitle: modeConfig?.isByod == true
              ? Text(
                  modeConfig!.byodUrl ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: syncColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              syncLabel,
              style: TextStyle(color: syncColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const _CustomDivider(),
        ListTile(
          leading: Icon(Icons.swap_horiz, color: Colors.grey[400]),
          title: const Text('Switch Storage Mode'),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => _showSwitchModeDialog(context, ref),
        ),
        if (modeConfig?.isSyncEnabled == true) ...[
          const _CustomDivider(),
          ListTile(
            leading: Icon(Icons.sync, color: Colors.grey[400]),
            title: const Text('Sync Now'),
            trailing: syncState == SyncState.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: syncState == SyncState.syncing
                ? null
                : () => ref.read(syncProvider.notifier).triggerSync(),
          ),
        ],
      ],
    );
  }

  void _showSwitchModeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Switch Storage Mode'),
        content: const Text(
          'Switching modes requires resetting the app flow. '
          'Your local vault data will be preserved.\n\n'
          'You will be returned to the mode selection screen.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(storageModeProvider.notifier).clear();
              // Lock vault and go back to first screen
              ref.read(authProvider.notifier).lockVault();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Switch Mode'),
          ),
        ],
      ),
    );
  }
}
