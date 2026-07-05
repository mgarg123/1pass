import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'supabase_auth_screen.dart';
import '../../vault/ui/vault_list_screen.dart';
import '../../../core/updater/update_service.dart';
import '../../../core/updater/update_dialog.dart';

import '../../settings/providers/auto_lock_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final release = await updateService.checkForUpdates();
    if (release != null && mounted) {
      UpdateDialog.show(context, release);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(autoLockProvider.notifier).userActivityDetected(),
        child: const VaultListScreen(),
      );
    }

    final isSupabaseAuth = ref.read(authProvider.notifier).isSupabaseAuthenticated;

    if (!isSupabaseAuth) {
      return const SupabaseAuthScreen();
    }

    final hasAccountAsync = ref.watch(hasAccountProvider);

    return hasAccountAsync.when(
      data: (hasAccount) => hasAccount ? const LoginScreen() : const SignupScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error loading account state: $e'))),
    );
  }
}
