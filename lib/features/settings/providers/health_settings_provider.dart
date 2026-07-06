import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/hive_setup.dart';

class FlagOldPasswordsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final stored = HiveSetup.metaBox.get('flag_old_passwords') as bool?;
    return stored ?? false; // Off by default as per NIST guidance
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveSetup.metaBox.put('flag_old_passwords', enabled);
  }
}

final flagOldPasswordsProvider = NotifierProvider<FlagOldPasswordsNotifier, bool>(FlagOldPasswordsNotifier.new);
