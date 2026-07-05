import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/biometric_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _didAutoPromptBiometrics = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoPromptBiometrics) {
      _didAutoPromptBiometrics = true;
      final biometricState = ref.read(biometricProvider);
      if (biometricState.isEnabled && !ref.read(biometricProvider.notifier).isMasterPasswordRequired()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authProvider.notifier).unlockWithBiometrics();
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) return;
    await ref.read(authProvider.notifier).unlockVault(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/images/1pass.png',
                    height: 120,
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOut),
                ),
                const SizedBox(height: 32),
                Text(
                  'Unlock Vault',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                const SizedBox(height: 48),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: authState.isAuthenticating ? null : _submit,
                  child: authState.isAuthenticating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Unlock'),
                ),
                if (ref.watch(biometricProvider).isEnabled) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: authState.isAuthenticating
                        ? null
                        : () => ref.read(authProvider.notifier).unlockWithBiometrics(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with Biometrics'),
                  ),
                ],
              ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            ),
          ),
        ),
      ),
    );
  }
}
