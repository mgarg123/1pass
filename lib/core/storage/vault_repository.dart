import 'dart:convert';
import 'dart:typed_data';
import '../../features/vault/models/vault_entry.dart';
import '../crypto/crypto_models.dart';
import '../crypto/crypto_service.dart';
import 'hive_setup.dart';

abstract class VaultRepository {
  Future<List<VaultEntry>> getAllEntries(EncryptionKey key);
  Future<void> saveEntry(VaultEntry entry, EncryptionKey key);
  Future<void> deleteEntry(String id);
  Future<void> saveSalt(Salt salt);
  Future<Salt?> getSalt();
  Future<void> clearVault();
}

class HiveVaultRepository implements VaultRepository {
  final CryptoService _cryptoService;

  HiveVaultRepository(this._cryptoService);

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
        title: data['title'] as String,
        username: decryptedJson['username'] as String,
        password: decryptedJson['password'] as String,
        url: decryptedJson['url'] as String?,
        notes: decryptedJson['notes'] as String?,
        tags: List<String>.from(data['tags'] ?? []),
        createdAt: DateTime.parse(data['createdAt'] as String),
        updatedAt: DateTime.parse(data['updatedAt'] as String),
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
      'title': entry.title,
      'tags': entry.tags,
      'createdAt': entry.createdAt.toIso8601String(),
      'updatedAt': entry.updatedAt.toIso8601String(),
      'encryptedData': blob.toStorageString(),
    };

    await box.put(entry.id, data);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await HiveSetup.vaultBox.delete(id);
  }

  @override
  Future<void> saveSalt(Salt salt) async {
    await HiveSetup.metaBox.put('user_salt', salt.toBase64());
  }

  @override
  Future<Salt?> getSalt() async {
    final saltStr = HiveSetup.metaBox.get('user_salt') as String?;
    if (saltStr == null) return null;
    return Salt.fromBase64(saltStr);
  }

  @override
  Future<void> clearVault() async {
    await HiveSetup.vaultBox.clear();
    await HiveSetup.metaBox.clear();
  }
}
