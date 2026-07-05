import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/vault/models/vault_entry.dart';
import '../crypto/crypto_models.dart';
import '../crypto/crypto_service.dart';
import 'vault_repository.dart';
import 'hive_setup.dart';

class SyncingVaultRepository implements VaultRepository {
  final VaultRepository _localRepository;
  final CryptoService _cryptoService;
  final SupabaseClient _supabase;

  SyncingVaultRepository(this._localRepository, this._cryptoService, this._supabase);

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

  /// Syncs data with Supabase.
  Future<void> sync(EncryptionKey key) async {
    if (_supabase.auth.currentUser == null) return;

    final userId = _supabase.auth.currentUser!.id;

    // 1. Pull changes from remote
    final lastSyncStr = HiveSetup.metaBox.get('last_sync_time') as String?;
    DateTime? lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

    var query = _supabase.from('vault_entries').select();
    if (lastSyncTime != null) {
      query = query.gt('updated_at', lastSyncTime.toUtc().toIso8601String());
    }

    final remoteEntries = await query;
    bool hasLocalChanges = false;
    
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
          hasLocalChanges = true;
          continue;
        }
      }

      // Remote is newer or entry doesn't exist locally
      final encryptedDataStr = remoteEntry['encrypted_data'] as String;
      final nonceStr = remoteEntry['nonce'] as String;
      
      // We need to parse our custom format vs Supabase schema.
      // Wait, in Phase 2 EncryptedBlob has nonce+cipherText+mac.
      // Supabase has encrypted_data and nonce separate.
      // Let's structure the blob to fit or modify how we save to Supabase.
      // For now, assume remote uses 'encrypted_data' as base64(ciphertext+mac) and 'nonce' as base64(nonce).
      // Let's adjust this to fit our EncryptedBlob format (nonce:ciphertext:mac).
      // Actually, since we control both, when we push, we can just split our blob.
      
      // Reconstruct blob from remote:
      // Our EncryptedBlob requires cipherText and mac. The cryptography package's cipherText includes MAC usually, 
      // but EncryptedBlob separates them. We will serialize/deserialize correctly below.
      // Wait, EncryptedBlob.fromStorageString expects nonce:cipherText:mac.
      // Let's just use the EncryptedBlob storage string in `encrypted_data` and ignore `nonce` column in Supabase, 
      // or populate it for schema compliance but use `encrypted_data` for the full string.
      // Let's use `encrypted_data` for the full `blob.toStorageString()` to simplify.
      
      final blob = EncryptedBlob.fromStorageString(encryptedDataStr);
      
      try {
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
        print('Failed to decrypt remote entry $id: $e');
        // Handle decrypt failure? Maybe skip it.
      }
    }

    // 2. Push local pending changes to remote
    final pendingKeys = HiveSetup.pendingSyncBox.keys.toList();
    for (final id in pendingKeys) {
      final localData = localEntriesBox.get(id) as Map?;
      if (localData == null) {
        await HiveSetup.pendingSyncBox.delete(id);
        continue;
      }
      
      final encryptedDataStr = localData['encryptedData'] as String;
      final blob = EncryptedBlob.fromStorageString(encryptedDataStr);

      await _supabase.from('vault_entries').upsert({
        'id': id,
        'user_id': userId,
        'encrypted_data': encryptedDataStr, // Includes nonce:ciphertext:mac
        'nonce': blob.nonce.toBase64(),     // Required by schema
        'created_at': localData['createdAt'],
        'updated_at': localData['updatedAt'],
        'is_deleted': localData['isDeleted'],
      });
      
      await HiveSetup.pendingSyncBox.delete(id);
    }
    
    // Update last sync time
    await HiveSetup.metaBox.put('last_sync_time', DateTime.now().toUtc().toIso8601String());
  }
}
