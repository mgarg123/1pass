import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vault/models/vault_entry.dart';
import '../../../core/sync/sync_provider.dart';

class VaultNotifier extends AsyncNotifier<List<VaultEntry>> {
  @override
  Future<List<VaultEntry>> build() async {
    return _loadEntriesInternal();
  }

  Future<List<VaultEntry>> _loadEntriesInternal() async {
    final authState = ref.read(authProvider);
    final key = authState.encryptionKey;
    if (key == null) return [];

    final repo = ref.read(vaultRepositoryProvider);
    final allEntries = await repo.getAllEntries(key);
    
    final now = DateTime.now();
    for (final e in allEntries) {
      if (e.isDeleted && now.difference(e.updatedAt).inDays >= 30) {
        await repo.hardDeleteEntry(e.id);
      }
    }

    final entries = allEntries.where((e) => !e.isDeleted).toList();
    entries.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return entries;
  }

  Future<void> _loadEntries() async {
    state = const AsyncValue.loading();
    try {
      final entries = await _loadEntriesInternal();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveEntry(VaultEntry entry) async {
    try {
      final key = ref.read(authProvider).encryptionKey;
      if (key == null) throw Exception('Not authenticated');

      final repo = ref.read(vaultRepositoryProvider);
      await repo.saveEntry(entry, key);
      
      // Reload list
      await _loadEntries();
      ref.invalidate(trashProvider);
      
      // Trigger sync
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      // Re-throw so UI can handle errors
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.deleteEntry(id);
      await _loadEntries();
      ref.invalidate(trashProvider);
      
      // Trigger sync
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleFavorite(VaultEntry entry) async {
    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await saveEntry(updated);
  }

  Future<void> restoreEntry(String id) async {
    try {
      final key = ref.read(authProvider).encryptionKey;
      if (key == null) throw Exception('Not authenticated');

      final repo = ref.read(vaultRepositoryProvider);
      final allEntries = await repo.getAllEntries(key);
      final entry = allEntries.firstWhere((e) => e.id == id);
      
      final updated = entry.copyWith(isDeleted: false, updatedAt: DateTime.now().toUtc());
      await repo.saveEntry(updated, key);
      
      await _loadEntries();
      ref.invalidate(trashProvider);
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> hardDeleteEntry(String id) async {
    try {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.hardDeleteEntry(id);
      
      await _loadEntries();
      ref.invalidate(trashProvider);
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> emptyTrash() async {
    try {
      final key = ref.read(authProvider).encryptionKey;
      if (key == null) throw Exception('Not authenticated');

      final repo = ref.read(vaultRepositoryProvider);
      final allEntries = await repo.getAllEntries(key);
      final trashEntries = allEntries.where((e) => e.isDeleted);
      
      for (final e in trashEntries) {
        await repo.hardDeleteEntry(e.id);
      }
      
      await _loadEntries();
      ref.invalidate(trashProvider);
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      rethrow;
    }
  }
}

final vaultProvider = AsyncNotifierProvider<VaultNotifier, List<VaultEntry>>(VaultNotifier.new);

final trashProvider = FutureProvider<List<VaultEntry>>((ref) async {
  final authState = ref.watch(authProvider);
  final key = authState.encryptionKey;
  if (key == null) return [];

  final repo = ref.read(vaultRepositoryProvider);
  final allEntries = await repo.getAllEntries(key);
  
  final now = DateTime.now();
  final trashEntries = allEntries.where((e) => e.isDeleted && now.difference(e.updatedAt).inDays < 30).toList();
  
  trashEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // most recent first
  return trashEntries;
});
