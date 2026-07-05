import 'package:hive_flutter/hive_flutter.dart';

class HiveSetup {
  static const String vaultBoxName = 'vault_entries';
  static const String metaBoxName = 'user_meta';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Open the unencrypted boxes.
    // The data inside vault_entries will be encrypted at the field level via CryptoService.
    await Hive.openBox(vaultBoxName);
    await Hive.openBox(metaBoxName);
  }

  static Box get vaultBox => Hive.box(vaultBoxName);
  static Box get metaBox => Hive.box(metaBoxName);
}
