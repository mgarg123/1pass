import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/hive_setup.dart';

class BreachSettingsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final stored = HiveSetup.metaBox.get('check_password_breaches') as bool?;
    return stored ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveSetup.metaBox.put('check_password_breaches', enabled);
  }
}

final breachSettingsProvider = NotifierProvider<BreachSettingsNotifier, bool>(BreachSettingsNotifier.new);
