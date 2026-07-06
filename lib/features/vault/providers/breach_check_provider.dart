import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/breach_checker_service.dart';
import '../../settings/providers/breach_settings_provider.dart';

final breachCheckerServiceProvider = Provider((ref) => BreachCheckerService());

class BreachCheckState {
  final bool isLoading;
  final int breachCount;
  final String checkedPassword;

  BreachCheckState({
    this.isLoading = false,
    this.breachCount = 0,
    this.checkedPassword = '',
  });

  BreachCheckState copyWith({
    bool? isLoading,
    int? breachCount,
    String? checkedPassword,
  }) {
    return BreachCheckState(
      isLoading: isLoading ?? this.isLoading,
      breachCount: breachCount ?? this.breachCount,
      checkedPassword: checkedPassword ?? this.checkedPassword,
    );
  }
}

class BreachCheckNotifier extends Notifier<BreachCheckState> {
  Timer? _debounceTimer;

  @override
  BreachCheckState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return BreachCheckState();
  }

  void checkPassword(String password) {
    final isEnabled = ref.read(breachSettingsProvider);
    if (!isEnabled || password.isEmpty) {
      _debounceTimer?.cancel();
      state = BreachCheckState();
      return;
    }

    if (password == state.checkedPassword && !state.isLoading) {
      return;
    }

    _debounceTimer?.cancel();
    
    state = state.copyWith(isLoading: true, checkedPassword: password, breachCount: 0);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final service = ref.read(breachCheckerServiceProvider);
      final count = await service.checkPasswordBreachCount(password);
      
      if (state.checkedPassword == password) {
        state = state.copyWith(isLoading: false, breachCount: count);
      }
    });
  }
}

final breachCheckProvider = NotifierProvider<BreachCheckNotifier, BreachCheckState>(BreachCheckNotifier.new);
