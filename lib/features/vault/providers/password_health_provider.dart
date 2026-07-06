import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vault/models/vault_entry.dart';
import '../../vault/providers/vault_provider.dart';
import '../../../core/services/breach_checker_service.dart';
import '../../settings/providers/health_settings_provider.dart';

class EntryHealth {
  final VaultEntry entry;
  final List<String> warnings; // 'weak', 'reused', 'old', 'pwned'
  final bool isOld;
  final bool? isPwned; // null means checking, true/false means checked

  EntryHealth({
    required this.entry,
    required this.warnings,
    required this.isOld,
    this.isPwned,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}

class PasswordHealthState {
  final List<EntryHealth> items;
  final bool isLoading;

  PasswordHealthState({required this.items, required this.isLoading});
}

class PasswordHealthNotifier extends AsyncNotifier<PasswordHealthState> {
  final BreachCheckerService _breachService = BreachCheckerService();
  final Map<String, int> _pwnedCache = {};
  bool _isCheckingBreaches = false;

  @override
  Future<PasswordHealthState> build() async {
    final entries = await ref.watch(vaultProvider.future);
    final flagOld = ref.watch(flagOldPasswordsProvider);

    final localState = _computeLocalState(entries, flagOld);

    // Schedule breach check asynchronously
    if (!_isCheckingBreaches) {
      _checkBreaches(entries);
    }

    return localState;
  }

  PasswordHealthState _computeLocalState(List<VaultEntry> entries, bool flagOld) {
    final passwordCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.password.isNotEmpty && !entry.isDeleted) {
        passwordCounts[entry.password] = (passwordCounts[entry.password] ?? 0) + 1;
      }
    }

    final healthItems = <EntryHealth>[];

    for (final entry in entries) {
      if (entry.password.isEmpty || entry.isDeleted) continue;

      final warnings = <String>[];

      // Weak Check
      if (_isWeak(entry.password) && !entry.ignoredWarnings.contains('weak')) {
        warnings.add('weak');
      }

      // Reused Check
      if (passwordCounts[entry.password]! > 1 && !entry.ignoredWarnings.contains('reused')) {
        warnings.add('reused');
      }

      // Old Check
      final isOld = entry.updatedAt.isBefore(DateTime.now().subtract(const Duration(days: 365)));
      if (isOld && flagOld && !entry.ignoredWarnings.contains('old')) {
        warnings.add('old');
      }

      // Determine Pwned State from Cache
      bool? isPwned;
      if (_pwnedCache.containsKey(entry.password)) {
        isPwned = _pwnedCache[entry.password]! > 0;
        if (isPwned && !entry.ignoredWarnings.contains('pwned')) {
          warnings.add('pwned');
        }
      }

      healthItems.add(EntryHealth(
        entry: entry,
        warnings: warnings,
        isOld: isOld,
        isPwned: isPwned,
      ));
    }

    return PasswordHealthState(items: healthItems, isLoading: _isCheckingBreaches);
  }

  bool _isWeak(String password) {
    if (password.length < 8) return true;
    if (password.length > 16) return false; // Long passphrases are not weak
    
    bool hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    
    // Weak if it doesn't have at least two types of characters (for passwords 8-16 chars)
    int types = (hasLetters ? 1 : 0) + (hasNumbers ? 1 : 0) + (hasSpecial ? 1 : 0);
    return types < 2;
  }

  Future<void> _checkBreaches(List<VaultEntry> entries) async {
    _isCheckingBreaches = true;
    
    // Notify loading
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(PasswordHealthState(items: currentState.items, isLoading: true));
    }

    final uniquePasswords = entries
        .where((e) => !e.isDeleted && e.password.isNotEmpty)
        .map((e) => e.password)
        .toSet();

    for (final password in uniquePasswords) {
      if (!_pwnedCache.containsKey(password)) {
        final count = await _breachService.checkPasswordBreachCount(password);
        if (count >= 0) {
          _pwnedCache[password] = count;
        } else {
          // Keep it null or mark as safe if network fails to avoid blocking forever
          // Let's just not cache failures so it retries later, or cache as 0 to avoid spamming
        }

        // Recompute and emit state dynamically as results come in
        if (state.value != null) {
           final updatedEntries = await ref.read(vaultProvider.future);
           final flagOld = ref.read(flagOldPasswordsProvider);
           final partialState = _computeLocalState(updatedEntries, flagOld);
           state = AsyncData(PasswordHealthState(items: partialState.items, isLoading: true));
        }
      }
    }

    _isCheckingBreaches = false;
    
    // Final emit
    if (state.value != null) {
      final updatedEntries = await ref.read(vaultProvider.future);
      final flagOld = ref.read(flagOldPasswordsProvider);
      state = AsyncData(_computeLocalState(updatedEntries, flagOld));
    }
  }

  Future<void> ignoreWarning(VaultEntry entry, String warning) async {
    final currentIgnored = List<String>.from(entry.ignoredWarnings);
    if (!currentIgnored.contains(warning)) {
      currentIgnored.add(warning);
      final updatedEntry = entry.copyWith(ignoredWarnings: currentIgnored);
      await ref.read(vaultProvider.notifier).saveEntry(updatedEntry);
      // State updates automatically because we watch vaultProvider
    }
  }
}

final passwordHealthProvider = AsyncNotifierProvider<PasswordHealthNotifier, PasswordHealthState>(
  PasswordHealthNotifier.new,
);
