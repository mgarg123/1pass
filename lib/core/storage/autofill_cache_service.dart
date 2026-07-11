import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'hive_setup.dart';
import 'vault_repository.dart';
import '../crypto/crypto_service.dart';
import '../crypto/crypto_models.dart';
import '../../features/vault/models/vault_entry.dart';

/// Writes a JSON cache of vault entries for the native Android autofill service.
/// This replaces the fragile approach of parsing Hive's binary format from Kotlin.
/// The cache file is written to the app's files directory at a known path.
class AutofillCacheService {
  static const String _cacheFileName = 'autofill_cache.json';
  static const String _pendingSavesFileName = 'autofill_pending_saves.json';

  /// Writes the current vault entries to the JSON cache file.
  /// Should be called after any save, delete, or sync operation.
  static Future<void> writeCache() async {
    if (!Platform.isAndroid) return;

    try {
      final box = HiveSetup.vaultBox;
      final entries = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final data = box.get(key) as Map?;
        if (data == null) continue;

        final isDeleted = data['isDeleted'] == true;
        if (isDeleted) continue;

        // Only include fields needed for autofill matching + decryption
        entries.add({
          'id': data['id'] as String? ?? '',
          'title': data['title'] as String? ?? '',
          'encryptedData': data['encryptedData'] as String? ?? '',
        });
      }

      final cacheData = {
        'version': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': entries,
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      
      // Write atomically: write to temp file then rename
      final tempFile = File('${dir.path}/.$_cacheFileName.tmp');
      await tempFile.writeAsString(jsonEncode(cacheData), flush: true);
      await tempFile.rename(file.path);

      debugPrint('AutofillCacheService: wrote ${entries.length} entries to cache');
    } catch (e) {
      debugPrint('AutofillCacheService: failed to write cache: $e');
    }
  }

  /// Processes pending save requests queued by SaveAuthActivity.
  /// Called on app startup/resume to handle credentials saved while the main
  /// Flutter engine wasn't running.
  static Future<void> processPendingSaves() async {
    if (!Platform.isAndroid) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_pendingSavesFileName');
      
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final List<dynamic> pendingSaves = jsonDecode(content);
      
      if (pendingSaves.isEmpty) {
        await file.delete();
        return;
      }

      // Get encryption key
      const storage = FlutterSecureStorage();
      final keyBase64 = await storage.read(key: 'biometric_derived_key');
      if (keyBase64 == null) {
        debugPrint('AutofillCacheService: No key found, skipping pending saves');
        return;
      }

      final keyBytes = base64Decode(keyBase64);
      final encryptionKey = EncryptionKey(keyBytes);
      final cryptoService = CryptoService();
      final repository = HiveVaultRepository(cryptoService);

      final existingEntries = await repository.getAllEntries(encryptionKey);
      int processed = 0;

      for (final save in pendingSaves) {
        try {
          final type = save['type'] as String? ?? 'password';
          final domain = save['domain'] as String? ?? '';
          final username = save['username'] as String? ?? '';
          final password = save['password'] as String? ?? '';
          
          final userHandle = save['userHandle'] as String? ?? '';
          final credentialId = save['credentialId'] as String? ?? '';
          final privateKey = save['privateKey'] as String? ?? '';

          if (domain.isEmpty && (username.isEmpty || password.isEmpty) && type != 'passkey') continue;

          // Fuzzy match against existing entries
          VaultEntry? match;
          for (final entry in existingEntries) {
            final t = domain.toLowerCase();
            final url = entry.url?.toLowerCase() ?? '';
            final title = entry.title.toLowerCase();

            bool isMatch = false;
            if (t.isNotEmpty && (url.contains(t) || t.contains(url) || title.contains(t) || t.contains(title))) {
              isMatch = true;
            } else if (t.isNotEmpty && url.isNotEmpty) {
              final cleanU = url.replaceAll('https://', '').replaceAll('http://', '').replaceAll('www.', '').split('/')[0];
              if (t.contains(cleanU) || cleanU.contains(t)) {
                isMatch = true;
              }
            }

            if (isMatch && entry.username == username) {
              match = entry;
              break;
            }
          }

          if (match != null) {
            // Update password if it changed or add passkey fields
            var updatedEntry = match;
            bool changed = false;
            if (type == 'password' && match.password != password) {
              updatedEntry = updatedEntry.copyWith(password: password);
              changed = true;
            } else if (type == 'passkey' && credentialId.isNotEmpty) {
              updatedEntry = updatedEntry.copyWith(
                passkeyRelyingPartyId: domain,
                passkeyUserHandle: userHandle,
                passkeyPublicKey: '', // not strictly needed in Vault
                passkeyPrivateKey: privateKey,
              );
              changed = true;
            }
            if (changed) {
              updatedEntry = updatedEntry.copyWith(updatedAt: DateTime.now().toUtc());
              await repository.saveEntry(updatedEntry, encryptionKey);
            }
          } else {
            // Create new entry
            var newEntry = VaultEntry(
              id: const Uuid().v4(),
              title: domain.isNotEmpty ? domain : (type == 'passkey' ? 'Passkey' : 'Saved Credential'),
              username: username,
              password: password,
              url: domain,
              notes: '',
              tags: const [],
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
            if (type == 'passkey' && credentialId.isNotEmpty) {
              newEntry = newEntry.copyWith(
                passkeyRelyingPartyId: domain,
                passkeyUserHandle: userHandle,
                passkeyPublicKey: '',
                passkeyPrivateKey: privateKey,
              );
            }
            await repository.saveEntry(newEntry, encryptionKey);
          }
          processed++;
        } catch (e) {
          debugPrint('AutofillCacheService: failed to process save: $e');
        }
      }

      // Delete pending file after processing
      await file.delete();
      debugPrint('AutofillCacheService: processed $processed pending saves');

      // Refresh the autofill cache with updated entries
      if (processed > 0) {
        await writeCache();
      }
    } catch (e) {
      debugPrint('AutofillCacheService: failed to process pending saves: $e');
    }
  }

  /// Deletes the cache file (e.g. on logout or vault clear).
  static Future<void> clearCache() async {
    if (!Platform.isAndroid) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('AutofillCacheService: failed to clear cache: $e');
    }
  }
}
