import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChangeMasterPasswordScreen extends ConsumerStatefulWidget {
  const ChangeMasterPasswordScreen({super.key});

  @override
  ConsumerState<ChangeMasterPasswordScreen> createState() => _ChangeMasterPasswordScreenState();
}

class _ChangeMasterPasswordScreenState extends ConsumerState<ChangeMasterPasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
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
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      return;
    }
    if (_newPasswordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New master password must be at least 8 characters')),
      );
      return;
    }

    try {
      await ref.read(authProvider.notifier).changeMasterPassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master password changed successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Master Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        'This will re-encrypt your entire vault. Do not close the app during this process. Make sure you remember your new password!',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Current Master Password',
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureText,
                onChanged: _evaluateStrength,
                decoration: const InputDecoration(
                  labelText: 'New Master Password',
                  prefixIcon: Icon(Icons.lock_outline),
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
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: authState.isAuthenticating ? null : _submit,
                child: authState.isAuthenticating
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Change Password'),
              ),
            ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          ),
        ),
      ),
    );
  }
}
