import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureText = true;
  String _passwordStrength = '';

  void _evaluateStrength(String value) {
    if (value.isEmpty) {
      _passwordStrength = '';
    } else if (value.length < 8) {
      _passwordStrength = 'Weak: Too short';
    } else if (!value.contains(RegExp(r'[A-Z]'))) {
      _passwordStrength = 'Medium: Add uppercase';
    } else if (!value.contains(RegExp(r'[0-9]'))) {
      _passwordStrength = 'Medium: Add numbers';
    } else if (!value.contains(RegExp(r'[!@#\$&*~]'))) {
      _passwordStrength = 'Strong: Consider adding symbols';
    } else {
      _passwordStrength = 'Very Strong';
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password must be at least 8 characters')),
      );
      return;
    }

    await ref.read(authProvider.notifier).signup(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Master Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 32),
              const Text(
                'Welcome to 1Pass',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If you forget your master password, your data cannot be recovered. There is no password reset.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                onChanged: _evaluateStrength,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              if (_passwordStrength.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Text(
                    _passwordStrength,
                    style: TextStyle(
                      color: _passwordStrength.contains('Weak') 
                          ? Colors.red 
                          : _passwordStrength.contains('Medium') 
                              ? Colors.orange 
                              : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: _obscureText,
                decoration: const InputDecoration(
                  labelText: 'Confirm Master Password',
                  border: OutlineInputBorder(),
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
                    : const Text('Create Vault'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
