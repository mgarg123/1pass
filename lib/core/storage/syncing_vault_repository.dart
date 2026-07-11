import 'dart:convert';
import '../../features/vault/models/vault_entry.dart';
import '../crypto/crypto_models.dart';
import '../crypto/crypto_service.dart';
import 'vault_repository.dart';
import 'hive_setup.dart';
import 'autofill_cache_service.dart';
import '../sync/sync_backend.dart';

/// A VaultRepository that wraps a local repository and syncs changes
/// to a remote backend via the [SyncBackend] abstraction.
///
/// This works identically regardless of whether the backend is Supabase,
/// a BYOD REST API, or any other implementation.
class SyncingVaultRepository implements VaultRepository {
  final VaultRepository _localRepository;
  final CryptoService _cryptoService;
  final SyncBackend _syncBackend;

  SyncingVaultRepository(this._localRepository, this._cryptoService, this._syncBackend);

  @override
  Future<List<VaultEntry>> getAllEntries(EncryptionKey key) {
    return _localRepository.getAllEntries(key);
  }

  @override
  Future<void> saveEntry(VaultEntry entry, EncryptionKey key) async {
    // Save locally first
    await _localRepository.saveEntry(entry, key);
    // Queue for sync
    await _queueForSync(entry.id);
  }

  @override
  Future<void> deleteEntry(String id) async {
    // Soft delete locally
    await _localRepository.deleteEntry(id);
    // Queue for sync
    await _queueForSync(id);
  }

  @override
  Future<void> hardDeleteEntry(String id) async {
    await _localRepository.hardDeleteEntry(id);
    // Remote syncing backend currently does not support hard deletes.
    // It will remain soft-deleted remotely.
  }

  @override
  Future<void> saveMeta(Salt salt, Argon2Params params, String verificationBlob) async {
    await _localRepository.saveMeta(salt, params, verificationBlob);
  }

  @override
  Future<LocalUserMeta?> getMeta() async {
    return _localRepository.getMeta();
  }

  @override
  Future<void> clearVault() async {
    await _localRepository.clearVault();
    await HiveSetup.pendingSyncBox.clear();
  }

  Future<void> _queueForSync(String id) async {
    await HiveSetup.pendingSyncBox.put(id, true);
  }

  /// Syncs data with the remote backend.
  Future<void> sync(EncryptionKey key) async {
    if (!_syncBackend.isReady) return;

    // 1. Pull changes from remote
    final lastSyncStr = HiveSetup.metaBox.get('last_sync_time') as String?;
    DateTime? lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

    final remoteEntries = await _syncBackend.pullEntries(since: lastSyncTime);
    
    // Resolve conflicts and save remote entries locally
    final localEntriesBox = HiveSetup.vaultBox;
    for (final remoteEntry in remoteEntries) {
      final id = remoteEntry['id'] as String;
      final remoteUpdatedAt = DateTime.parse(remoteEntry['updated_at'] as String);
      final isDeleted = remoteEntry['is_deleted'] as bool;
      
      final localData = localEntriesBox.get(id) as Map?;
      
      if (localData != null) {
        final localUpdatedAt = DateTime.parse(localData['updatedAt'] as String);
        if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
          // Local is newer, let it be pushed
          await _queueForSync(id);
          continue;
        }
      }

      // Remote is newer or entry doesn't exist locally
      final encryptedDataStr = remoteEntry['encrypted_data'] as String;
      
      try {
        final blob = EncryptedBlob.fromStorageString(encryptedDataStr);
        final decryptedBytes = await _cryptoService.decrypt(blob, key);
        final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
        
        final localEntryMap = {
          'id': id,
          'title': decryptedJson['title'] ?? 'Imported Entry',
          'tags': List<String>.from(decryptedJson['tags'] ?? []),
          'createdAt': remoteEntry['created_at'],
          'updatedAt': remoteEntry['updated_at'],
          'isDeleted': isDeleted,
          'encryptedData': encryptedDataStr, // save the storage string locally
        };
        
        await localEntriesBox.put(id, localEntryMap);
        // Remove from sync queue if it was there
        await HiveSetup.pendingSyncBox.delete(id);
      } catch (e) {
        // Decrypt error — skip this entry silently
      }
    }

    // 2. Push local pending changes to remote
    final pendingKeys = HiveSetup.pendingSyncBox.keys.toList();
    final entriesToPush = <Map<String, dynamic>>[];
    final pushedIds = <dynamic>[];

    for (final id in pendingKeys) {
      final localData = localEntriesBox.get(id) as Map?;
      if (localData == null) {
        await HiveSetup.pendingSyncBox.delete(id);
        continue;
      }
      
      final encryptedDataStr = localData['encryptedData'] as String;
      final blob = EncryptedBlob.fromStorageString(encryptedDataStr);

      entriesToPush.add({
        'id': id,
        'encrypted_data': encryptedDataStr,
        'nonce': blob.nonce.toBase64(),
        'created_at': localData['createdAt'],
        'updated_at': localData['updatedAt'],
        'is_deleted': localData['isDeleted'],
      });
      pushedIds.add(id);
    }

    if (entriesToPush.isNotEmpty) {
      await _syncBackend.pushEntries(entriesToPush);
      for (final id in pushedIds) {
        await HiveSetup.pendingSyncBox.delete(id);
      }
    }
    
    // Update last sync time
    await HiveSetup.metaBox.put('last_sync_time', DateTime.now().toUtc().toIso8601String());
    // Update autofill cache after sync
    await AutofillCacheService.writeCache();
  }
}
