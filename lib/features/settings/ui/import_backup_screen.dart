import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backup_provider.dart';

class ImportBackupScreen extends ConsumerStatefulWidget {
  final String backupJson;

  const ImportBackupScreen({super.key, required this.backupJson});

  @override
  ConsumerState<ImportBackupScreen> createState() => _ImportBackupScreenState();
}

class _ImportBackupScreenState extends ConsumerState<ImportBackupScreen> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isImporting = false;
  String? _error;

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      await ref.read(backupProvider).importVault(widget.backupJson, _passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported successfully!')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Backup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.file_download, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Enter Master Password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter the master password that was used when this backup was created.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Backup Master Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isImporting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isImporting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Import Vault'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
