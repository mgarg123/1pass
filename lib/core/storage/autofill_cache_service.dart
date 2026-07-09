import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'hive_setup.dart';

/// Writes a JSON cache of vault entries for the native Android autofill service.
/// This replaces the fragile approach of parsing Hive's binary format from Kotlin.
/// The cache file is written to the app's files directory at a known path.
class AutofillCacheService {
  static const String _cacheFileName = 'autofill_cache.json';

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
