import 'dart:convert';
import 'dart:typed_data';
import '../../features/vault/models/vault_entry.dart';
import '../../features/vault/models/entry_type.dart';
import '../crypto/crypto_models.dart';
import '../crypto/crypto_service.dart';
import 'hive_setup.dart';
import 'autofill_cache_service.dart';

class LocalUserMeta {
  final Salt salt;
  final Argon2Params? argon2Params;
  final String? verificationBlob;

  LocalUserMeta({
    required this.salt,
    this.argon2Params,
    this.verificationBlob,
  });
}

abstract class VaultRepository {
  Future<List<VaultEntry>> getAllEntries(EncryptionKey key);
  Future<void> saveEntry(VaultEntry entry, EncryptionKey key);
  Future<void> deleteEntry(String id);
  Future<void> saveMeta(Salt salt, Argon2Params params, String verificationBlob);
  Future<LocalUserMeta?> getMeta();
  Future<void> clearVault();
}

class HiveVaultRepository implements VaultRepository {
  final CryptoService _cryptoService;

  HiveVaultRepository(this._cryptoService);

  EntryType _parseEntryType(String? typeStr) {
    if (typeStr == null) return EntryType.login;
    return EntryType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => EntryType.login,
    );
  }

  @override
  Future<List<VaultEntry>> getAllEntries(EncryptionKey key) async {
    final box = HiveSetup.vaultBox;
    final entries = <VaultEntry>[];

    for (final keyInBox in box.keys) {
      final data = box.get(keyInBox) as Map;
      
      final encryptedDataStr = data['encryptedData'] as String;
      final blob = EncryptedBlob.fromStorageString(encryptedDataStr);
      
      final decryptedBytes = await _cryptoService.decrypt(blob, key);
      final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;

      entries.add(VaultEntry(
        id: data['id'] as String,
        type: _parseEntryType(decryptedJson['type'] as String?),
        title: (decryptedJson['title'] as String?) ?? (data['title'] as String),
        username: decryptedJson['username'] as String,
        password: decryptedJson['password'] as String,
        url: decryptedJson['url'] as String?,
        notes: decryptedJson['notes'] as String?,
        totpSecret: decryptedJson['totpSecret'] as String?,
        cardNumber: decryptedJson['cardNumber'] as String?,
        cardholderName: decryptedJson['cardholderName'] as String?,
        expiryDate: decryptedJson['expiryDate'] as String?,
        cvv: decryptedJson['cvv'] as String?,
        pin: decryptedJson['pin'] as String?,
        bankName: decryptedJson['bankName'] as String?,
        tags: decryptedJson['tags'] != null 
            ? List<String>.from(decryptedJson['tags']) 
            : List<String>.from(data['tags'] ?? []),
        ignoredWarnings: decryptedJson['ignoredWarnings'] != null
            ? List<String>.from(decryptedJson['ignoredWarnings'])
            : [],
        passwordHistory: decryptedJson['passwordHistory'] != null
            ? (decryptedJson['passwordHistory'] as List)
                .map((e) => PasswordHistoryItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : [],
        createdAt: DateTime.parse(data['createdAt'] as String),
        updatedAt: DateTime.parse(data['updatedAt'] as String),
        isDeleted: data['isDeleted'] == true,
        isFavorite: (decryptedJson['isFavorite'] as bool?) ?? (data['isFavorite'] as bool?) ?? false,
      ));
    }

    return entries;
  }

  @override
  Future<void> saveEntry(VaultEntry entry, EncryptionKey key) async {
    final box = HiveSetup.vaultBox;
    
    final payloadString = entry.sensitivePayload;
    final payloadBytes = Uint8List.fromList(utf8.encode(payloadString));
    
    final blob = await _cryptoService.encrypt(payloadBytes, key);

    final data = {
      'id': entry.id,
      'type': entry.type.name,
      'title': entry.title,
      'tags': entry.tags,
      'createdAt': entry.createdAt.toIso8601String(),
      'updatedAt': entry.updatedAt.toIso8601String(),
      'isDeleted': entry.isDeleted,
      'isFavorite': entry.isFavorite,
      'encryptedData': blob.toStorageString(),
    };

    await box.put(entry.id, data);
    // Update autofill cache for native Android autofill service
    await AutofillCacheService.writeCache();
  }

  @override
  Future<void> deleteEntry(String id) async {
    final box = HiveSetup.vaultBox;
    final data = box.get(id);
    if (data != null) {
      final updatedData = Map<dynamic, dynamic>.from(data as Map);
      updatedData['isDeleted'] = true;
      
      final currentUpdatedAt = DateTime.parse(data['updatedAt'] as String);
      DateTime newUpdatedAt = DateTime.now().toUtc();
      if (!newUpdatedAt.isAfter(currentUpdatedAt)) {
        newUpdatedAt = currentUpdatedAt.add(const Duration(milliseconds: 1));
      }
      updatedData['updatedAt'] = newUpdatedAt.toIso8601String();
      
      await box.put(id, updatedData);
      // Update autofill cache for native Android autofill service
      await AutofillCacheService.writeCache();
    }
  }

  @override
  Future<void> saveMeta(Salt salt, Argon2Params params, String verificationBlob) async {
    await HiveSetup.metaBox.put('user_salt', salt.toBase64());
    await HiveSetup.metaBox.put('argon2_params', params.toJson());
    await HiveSetup.metaBox.put('verification_blob', verificationBlob);
  }

  @override
  Future<LocalUserMeta?> getMeta() async {
    final saltStr = HiveSetup.metaBox.get('user_salt') as String?;
    if (saltStr == null) return null;
    
    final paramsJson = HiveSetup.metaBox.get('argon2_params') as Map?;
    final verificationBlob = HiveSetup.metaBox.get('verification_blob') as String?;

    return LocalUserMeta(
      salt: Salt.fromBase64(saltStr),
      argon2Params: paramsJson != null ? Argon2Params.fromJson(Map<String, dynamic>.from(paramsJson)) : null,
      verificationBlob: verificationBlob,
    );
  }

  @override
  Future<void> clearVault() async {
    await HiveSetup.vaultBox.clear();
    await HiveSetup.metaBox.clear();
    // Clear autofill cache on vault reset
    await AutofillCacheService.clearCache();
  }
}
