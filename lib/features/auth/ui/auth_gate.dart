import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../../vault/ui/vault_list_screen.dart';

import '../../settings/providers/auto_lock_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(autoLockProvider.notifier).userActivityDetected(),
        child: const VaultListScreen(),
      );
    }

    final hasAccountAsync = ref.watch(hasAccountProvider);

    return hasAccountAsync.when(
      data: (hasAccount) => hasAccount ? const LoginScreen() : const SignupScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error loading account state: $e'))),
    );
  }
}
