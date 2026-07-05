import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auto_lock_provider.dart';

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
          ListTile(
            title: const Text('Change Master Password'),
            subtitle: const Text('Update your master password and re-encrypt vault'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Phase 4
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changing master password is part of Phase 4!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
