import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import 'recovery_key_modal.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isKeyVerified = false;
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _recoveryKeyController.text = data.text!.trim();
      });
    }
  }

  Future<void> _pickRecoveryFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String? content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        content = await ioFile.readAsString();
      }

      if (content == null || content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file.')),
          );
        }
        return;
      }

      final regex = RegExp(
        r'OP-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}',
        caseSensitive: false,
      );
      final match = regex.firstMatch(content);

      if (match != null) {
        final key = match.group(0)!;
        setState(() {
          _recoveryKeyController.text = key;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Found recovery key in file! Verifying...')),
          );
        }
        await _verifyRecoveryKey();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid 1Pass Emergency Recovery Key found in file.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading recovery file: $e')),
        );
      }
    }
  }

  Future<void> _verifyRecoveryKey() async {
    final key = _recoveryKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Emergency Recovery Key')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).unlockWithRecoveryKey(key);
    if (success && mounted) {
      setState(() {
        _isKeyVerified = true;
      });
    }
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password must be at least 8 characters')),
      );
      return;
    }

    try {
      final newRecoveryKey = await ref
          .read(authProvider.notifier)
          .resetMasterPasswordWithActiveKey(newPassword: newPassword);

      if (mounted) {
        await RecoveryKeyModal.show(
          context,
          recoveryKey: newRecoveryKey,
          isDismissible: false,
        );

        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      // Handled via AuthState errorMessage
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_isKeyVerified ? 'Reset Master Password' : 'Vault Recovery'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: _isKeyVerified
                ? _buildResetPasswordView(authState)
                : _buildEnterRecoveryKeyView(authState),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterRecoveryKeyView(AuthState authState) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              size: 42,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recover Your Vault',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your Emergency Recovery Key or upload your saved Emergency Kit file to restore access.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _recoveryKeyController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: 'Emergency Recovery Key',
            hintText: 'OP-XXXX-XXXX-XXXX-...',
            prefixIcon: const Icon(Icons.shield_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste_rounded),
              tooltip: 'Paste from clipboard',
              onPressed: _pasteFromClipboard,
            ),
          ),
        ),
        const SizedBox(height: 24),
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
          onPressed: authState.isAuthenticating ? null : _verifyRecoveryKey,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: authState.isAuthenticating
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify & Recover Vault'),
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFF222222))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: Color(0xFF222222))),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: authState.isAuthenticating ? null : _pickRecoveryFile,
          icon: const Icon(Icons.upload_file_rounded, size: 20),
          label: const Text('Upload Emergency Kit File (.txt)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF333333)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildResetPasswordView(AuthState authState) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 42,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recovery Successful!',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Please choose a new Master Password to re-encrypt and protect your vault.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureText,
          onChanged: _evaluateStrength,
          decoration: InputDecoration(
            labelText: 'New Master Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
          ),
        ),
        if (_passwordStrength.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              _passwordStrength,
              style: TextStyle(
                color: _passwordStrength.startsWith('Weak')
                    ? Colors.redAccent
                    : _passwordStrength.startsWith('Medium')
                        ? Colors.orangeAccent
                        : primaryColor,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureText,
          decoration: const InputDecoration(
            labelText: 'Confirm New Master Password',
            prefixIcon: Icon(Icons.lock_reset_outlined),
          ),
        ),
        const SizedBox(height: 24),
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
          onPressed: authState.isAuthenticating ? null : _submitNewPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: authState.isAuthenticating
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Password & Enter Vault'),
        ),
      ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
