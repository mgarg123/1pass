import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/vault_provider.dart';
import 'widgets/entry_avatar_widget.dart';
import '../models/vault_entry.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Recently Deleted'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Empty Trash',
            onPressed: () async {
              final entries = trashAsync.value ?? [];
              if (entries.isEmpty) return;
              
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1C1C1E),
                  title: const Text('Empty Trash?', style: TextStyle(color: Colors.white)),
                  content: const Text('All items will be permanently deleted. This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Empty Trash', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                ref.read(vaultProvider.notifier).emptyTrash();
              }
            },
          ),
        ],
      ),
      body: trashAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text(
                    'Trash is empty',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final daysLeft = 30 - DateTime.now().difference(entry.updatedAt).inDays;
              
              return Dismissible(
                key: Key(entry.id),
                background: Container(
                  color: Colors.green[700],
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.restore, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red[700],
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_forever, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Restore
                    ref.read(vaultProvider.notifier).restoreEntry(entry.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${entry.title} restored')),
                    );
                    return true;
                  } else {
                    // Hard Delete
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text('Permanently Delete?', style: TextStyle(color: Colors.white)),
                        content: Text('Are you sure you want to permanently delete "${entry.title}"? This cannot be undone.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(vaultProvider.notifier).hardDeleteEntry(entry.id);
                      return true;
                    }
                    return false;
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: EntryAvatarWidget(entry: entry),
                  title: Text(
                    entry.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Permanently deletes in $daysLeft days',
                    style: TextStyle(color: Colors.red[300], fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.greenAccent),
                        tooltip: 'Restore',
                        onPressed: () {
                          ref.read(vaultProvider.notifier).restoreEntry(entry.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${entry.title} restored')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        tooltip: 'Permanently Delete',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1C1C1E),
                              title: const Text('Permanently Delete?', style: TextStyle(color: Colors.white)),
                              content: Text('Are you sure you want to permanently delete "${entry.title}"? This cannot be undone.', style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(vaultProvider.notifier).hardDeleteEntry(entry.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
        error: (err, st) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}
