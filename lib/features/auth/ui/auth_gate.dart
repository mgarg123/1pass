import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'supabase_auth_screen.dart';
import '../../vault/ui/vault_list_screen.dart';
import '../../../core/updater/update_service.dart';
import '../../../core/updater/update_dialog.dart';
import '../../../core/config/storage_mode.dart';
import '../../onboarding/ui/welcome_screen.dart';
import '../../onboarding/ui/mode_selection_screen.dart';

import '../../settings/providers/auto_lock_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _showWelcome = true;

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
    final modeConfig = ref.watch(storageModeProvider);
    final authState = ref.watch(authProvider);

    // ── Step 0: No mode selected → Show Welcome then Mode selection ──
    if (modeConfig == null) {
      if (_showWelcome) {
        return WelcomeScreen(
          onGetStarted: () {
            setState(() {
              _showWelcome = false;
            });
          },
        );
      }
      return const ModeSelectionScreen();
    }

    // ── Step 1: Vault already unlocked → Show vault ──
    if (authState.isAuthenticated) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(autoLockProvider.notifier).userActivityDetected(),
        child: const VaultListScreen(),
      );
    }

    // ── Step 2: Mode-specific remote auth ──
    switch (modeConfig.mode) {
      case StorageMode.cloudSync:
        // Cloud mode requires Supabase authentication first
        final isSupabaseAuth = ref.read(authProvider.notifier).isRemoteAuthenticated;
        if (!isSupabaseAuth) {
          return const SupabaseAuthScreen();
        }
        break;

      case StorageMode.localOnly:
        // No remote auth needed — fall through to master password
        break;

      case StorageMode.byodSync:
        // BYOD auth is via stored API key — fall through to master password
        break;
    }

    // ── Step 3: Check for existing vault → Login or Signup ──
    final hasAccountAsync = ref.watch(hasAccountProvider);

    return hasAccountAsync.when(
      data: (hasAccount) => hasAccount ? const LoginScreen() : const SignupScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error loading account state: $e'))),
    );
  }
}
