import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/password_health_provider.dart';
import 'add_edit_entry_screen.dart';

class PasswordHealthScreen extends ConsumerWidget {
  const PasswordHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthStateAsync = ref.watch(passwordHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Health'),
      ),
      body: healthStateAsync.when(
        data: (healthState) {
          final itemsWithWarnings = healthState.items.where((item) => item.hasWarnings).toList();
          
          if (itemsWithWarnings.isEmpty && !healthState.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Your vault is healthy!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (healthState.isLoading)
                const LinearProgressIndicator(),
              if (itemsWithWarnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${itemsWithWarnings.length} items need attention',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: itemsWithWarnings.length,
                  itemBuilder: (context, index) {
                    final item = itemsWithWarnings[index];
                    return _buildHealthItemTile(context, ref, item);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHealthItemTile(BuildContext context, WidgetRef ref, EntryHealth item) {
    return ExpansionTile(
      leading: Icon(_getIconForWarnings(item.warnings), color: _getColorForWarnings(item.warnings)),
      title: Text(item.entry.title.isNotEmpty ? item.entry.title : 'Unnamed Item'),
      subtitle: Text(item.entry.username.isNotEmpty ? item.entry.username : 'No username'),
      children: [
        if (item.isOld)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Last changed over a year ago', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ...item.warnings.map((warning) => ListTile(
          dense: true,
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          title: Text(_getWarningText(warning)),
          trailing: TextButton(
            onPressed: () {
              ref.read(passwordHealthProvider.notifier).ignoreWarning(item.entry, warning);
            },
            child: const Text('Ignore'),
          ),
        )),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditEntryScreen(entry: item.entry),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Fix Issue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getColorForWarnings(item.warnings).withOpacity(0.1),
                  foregroundColor: _getColorForWarnings(item.warnings),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForWarnings(List<String> warnings) {
    if (warnings.contains('pwned')) return Icons.gpp_bad;
    if (warnings.contains('weak')) return Icons.security;
    if (warnings.contains('reused')) return Icons.copy;
    return Icons.warning;
  }

  Color _getColorForWarnings(List<String> warnings) {
    if (warnings.contains('pwned')) return Colors.red;
    if (warnings.contains('weak')) return Colors.orange;
    if (warnings.contains('reused')) return Colors.orange;
    return Colors.amber;
  }

  String _getWarningText(String warning) {
    switch (warning) {
      case 'pwned': return 'Password has been exposed in a data breach.';
      case 'weak': return 'Password is weak and easy to guess.';
      case 'reused': return 'Password is used across multiple accounts.';
      case 'old': return 'Password is old and should be updated.';
      default: return 'Unknown issue.';
    }
  }
}
