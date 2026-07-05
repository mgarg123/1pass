import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/biometric_provider.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 32),
              const Text(
                'Unlock Vault',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  border: const OutlineInputBorder(),
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
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: authState.isAuthenticating ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: authState.isAuthenticating
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
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
            ],
          ),
        ),
      ),
    );
  }
}
