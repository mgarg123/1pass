import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/vault_entry.dart';

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
    final entries = await repo.getAllEntries(key);
    entries.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
    } catch (e) {
      rethrow;
    }
  }
}

final vaultProvider = AsyncNotifierProvider<VaultNotifier, List<VaultEntry>>(VaultNotifier.new);
