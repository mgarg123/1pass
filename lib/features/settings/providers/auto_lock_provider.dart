import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/storage/hive_setup.dart';

class AutoLockNotifier extends Notifier<int> with WidgetsBindingObserver {
  DateTime? _lastActive;
  Timer? _timer;

  @override
  int build() {
    WidgetsBinding.instance.addObserver(this);
    _loadPreference();
    
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    
    return 120; // Default 2 minutes
  }

  Future<void> _loadPreference() async {
    final stored = HiveSetup.metaBox.get('auto_lock_seconds') as int?;
    if (stored != null) {
      state = stored;
    }
  }

  Future<void> setTimer(int seconds) async {
    state = seconds;
    await HiveSetup.metaBox.put('auto_lock_seconds', seconds);
    _resetTimer();
  }

  void userActivityDetected() {
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    if (state == 0) return; // 0 means never lock

    _timer = Timer(Duration(seconds: state), () {
      _lockApp();
    });
  }

  void _lockApp() {
    ref.read(authProvider.notifier).logout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _lastActive = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastActive != null && this.state != 0) {
        final inactiveDuration = DateTime.now().difference(_lastActive!);
        if (inactiveDuration.inSeconds >= this.state) {
          _lockApp();
        }
      }
      _lastActive = null;
      _resetTimer();
    } else if (state == AppLifecycleState.detached) {
      _lockApp();
    }
  }

}

final autoLockProvider = NotifierProvider<AutoLockNotifier, int>(AutoLockNotifier.new);
