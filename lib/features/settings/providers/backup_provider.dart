import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crypto/crypto_models.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/storage/hive_setup.dart';
import '../../../core/storage/vault_repository.dart';
import '../../vault/models/vault_entry.dart';
import '../../vault/models/entry_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vault/providers/vault_provider.dart';
import '../../../core/sync/sync_provider.dart';

final backupProvider = Provider((ref) => BackupService(ref));

class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  Future<void> exportVault() async {
    final metaBox = HiveSetup.metaBox;
    final vaultBox = HiveSetup.vaultBox;

    final salt = metaBox.get('user_salt');
    final params = metaBox.get('argon2_params');
    final blob = metaBox.get('verification_blob');

    if (salt == null || blob == null) {
      throw Exception('No vault to export.');
    }

    final entries = [];
    for (final key in vaultBox.keys) {
      final data = vaultBox.get(key) as Map;
      entries.add(data);
    }

    final backupData = {
      'version': 1,
      'salt': salt,
      'argon2_params': params,
      'verification_blob': blob,
      'entries': entries,
    };

    final jsonString = jsonEncode(backupData);
    final fileName = 'vault-backup-${DateTime.now().toIso8601String().split('T')[0]}.encrypted.json';

    final bytes = utf8.encode(jsonString);
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: 'application/json',
        )
      ],
      subject: 'My Vault Backup',
    );
  }

  Future<void> importVault(String jsonString, String masterPassword) async {
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    if (backupData['version'] != 1) {
      throw Exception('Unsupported backup version.');
    }

    final saltStr = backupData['salt'] as String;
    final verificationBlobStr = backupData['verification_blob'] as String;
    final entriesData = backupData['entries'] as List;

    final salt = Salt.fromBase64(saltStr);
    final blob = EncryptedBlob.fromStorageString(verificationBlobStr);

    final cryptoService = _ref.read(cryptoServiceProvider);

    // Verify password
    final backupKey = await cryptoService.deriveKey(password: masterPassword, salt: salt);
    try {
      final dec = await cryptoService.decrypt(blob, backupKey);
      if (utf8.decode(dec) != 'vault-verify') {
        throw Exception();
      }
    } catch (_) {
      backupKey.clear();
      throw Exception('Incorrect master password for this backup file.');
    }

    // Pass verification. Let's decrypt entries.
    final List<VaultEntry> importedEntries = [];
    for (final entryDataMap in entriesData) {
      final entryData = Map<String, dynamic>.from(entryDataMap as Map);
      final encryptedDataStr = entryData['encryptedData'] as String;
      final entryBlob = EncryptedBlob.fromStorageString(encryptedDataStr);
      
      try {
        final decryptedBytes = await cryptoService.decrypt(entryBlob, backupKey);
        final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;

        final typeStr = decryptedJson['type'] as String?;
        final entryType = typeStr != null 
            ? EntryType.values.firstWhere((e) => e.name == typeStr, orElse: () => EntryType.login) 
            : EntryType.login;

        importedEntries.add(VaultEntry(
          id: entryData['id'] as String,
          type: entryType,
          title: (decryptedJson['title'] as String?) ?? (entryData['title'] as String),
          username: decryptedJson['username'] as String? ?? '',
          password: decryptedJson['password'] as String? ?? '',
          url: decryptedJson['url'] as String?,
          notes: decryptedJson['notes'] as String?,
          totpSecret: decryptedJson['totpSecret'] as String?,
          cardNumber: decryptedJson['cardNumber'] as String?,
          cardholderName: decryptedJson['cardholderName'] as String?,
          expiryDate: decryptedJson['expiryDate'] as String?,
          cvv: decryptedJson['cvv'] as String?,
          pin: decryptedJson['pin'] as String?,
          bankName: decryptedJson['bankName'] as String?,
          passkeyRelyingPartyId: decryptedJson['passkeyRelyingPartyId'] as String?,
          passkeyUserHandle: decryptedJson['passkeyUserHandle'] as String?,
          passkeyPublicKey: decryptedJson['passkeyPublicKey'] as String?,
          passkeyPrivateKey: decryptedJson['passkeyPrivateKey'] as String?,
          wifiSsid: decryptedJson['wifiSsid'] as String?,
          wifiPassword: decryptedJson['wifiPassword'] as String?,
          wifiSecurityType: decryptedJson['wifiSecurityType'] as String?,
          wifiIsHidden: decryptedJson['wifiIsHidden'] as bool?,
          identityTitle: decryptedJson['identityTitle'] as String?,
          identityFirstName: decryptedJson['identityFirstName'] as String?,
          identityMiddleName: decryptedJson['identityMiddleName'] as String?,
          identityLastName: decryptedJson['identityLastName'] as String?,
          identityGender: decryptedJson['identityGender'] as String?,
          identityBirthDate: decryptedJson['identityBirthDate'] as String?,
          identityEmail: decryptedJson['identityEmail'] as String?,
          identityPhone: decryptedJson['identityPhone'] as String?,
          identityAddress1: decryptedJson['identityAddress1'] as String?,
          identityAddress2: decryptedJson['identityAddress2'] as String?,
          identityCity: decryptedJson['identityCity'] as String?,
          identityState: decryptedJson['identityState'] as String?,
          identityPostalCode: decryptedJson['identityPostalCode'] as String?,
          identityCountry: decryptedJson['identityCountry'] as String?,
          identityPassportNumber: decryptedJson['identityPassportNumber'] as String?,
          identityNationalId: decryptedJson['identityNationalId'] as String?,
          identityLicenseNumber: decryptedJson['identityLicenseNumber'] as String?,
          identityCompany: decryptedJson['identityCompany'] as String?,
          identityOccupation: decryptedJson['identityOccupation'] as String?,
          tags: decryptedJson['tags'] != null 
              ? List<String>.from(decryptedJson['tags']) 
              : List<String>.from(entryData['tags'] ?? []),
          ignoredWarnings: decryptedJson['ignoredWarnings'] != null
              ? List<String>.from(decryptedJson['ignoredWarnings'])
              : [],
          passwordHistory: decryptedJson['passwordHistory'] != null
              ? (decryptedJson['passwordHistory'] as List)
                  .map((e) => PasswordHistoryItem.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : [],
          customFields: decryptedJson['customFields'] != null
              ? (decryptedJson['customFields'] as List)
                  .map((e) => CustomField.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : [],
          createdAt: DateTime.parse(entryData['createdAt'] as String),
          updatedAt: DateTime.parse(entryData['updatedAt'] as String),
          isDeleted: entryData['isDeleted'] == true,
          isFavorite: (decryptedJson['isFavorite'] as bool?) ?? (entryData['isFavorite'] as bool?) ?? false,
        ));
      } catch (e) {
        // Skip corrupted entries
      }
    }

    backupKey.clear();

    // Now merge into current vault.
    // We use the current VaultRepository to save them. It will encrypt them with the current key.
    final currentKey = _ref.read(authProvider).encryptionKey;
    if (currentKey == null) {
       throw Exception("You must be logged in to import a backup.");
    }

    final vaultRepository = _ref.read(vaultRepositoryProvider);
    final currentEntries = await vaultRepository.getAllEntries(currentKey);
    final currentEntriesMap = { for (var e in currentEntries) e.id : e };

    for (final importedEntry in importedEntries) {
      // Force the imported entry to win against any current local state (including tombstones)
      // by artificially bumping its updatedAt timestamp to now.
      final forceWinEntry = importedEntry.copyWith(
          updatedAt: DateTime.now().toUtc().add(const Duration(milliseconds: 1))
      );
      await vaultRepository.saveEntry(forceWinEntry, currentKey);
    }
    
    // Refresh the vault list in the UI and trigger sync to push restored entries
    _ref.invalidate(vaultProvider);
    _ref.read(syncProvider.notifier).triggerSync();
  }
}
