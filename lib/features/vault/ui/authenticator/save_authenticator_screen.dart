import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../providers/vault_provider.dart';
import '../../utils/totp_util.dart';
import '../widgets/totp_display.dart';

class SaveAuthenticatorScreen extends ConsumerStatefulWidget {
  final String? initialSecret;

  const SaveAuthenticatorScreen({super.key, this.initialSecret});

  @override
  ConsumerState<SaveAuthenticatorScreen> createState() => _SaveAuthenticatorScreenState();
}

class _SaveAuthenticatorScreenState extends ConsumerState<SaveAuthenticatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _secretController;
  
  bool _isSaving = false;
  bool _obscureSecret = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _secretController = TextEditingController(text: widget.initialSecret ?? '');

    if (widget.initialSecret != null && widget.initialSecret!.isNotEmpty) {
      final parsed = TotpUtil.parse(widget.initialSecret!);
      if (parsed.issuer != null && parsed.issuer!.isNotEmpty) {
        _titleController.text = parsed.issuer!;
        if (parsed.accountName != null && parsed.accountName!.isNotEmpty) {
          _titleController.text += ' (${parsed.accountName!})';
        }
      } else if (parsed.accountName != null && parsed.accountName!.isNotEmpty) {
        _titleController.text = parsed.accountName!;
      }
      
      // Update the secret controller with just the raw secret for the UI
      _secretController.text = parsed.secret;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    final parsed = TotpUtil.parse(_secretController.text);
    if (!TotpUtil.isValidBase32(parsed.secret)) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid TOTP Secret. Must be valid Base32.')),
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final newEntry = VaultEntry(
      id: const Uuid().v4(),
      type: EntryType.authenticator,
      title: _titleController.text,
      username: '',
      password: '',
      totpSecret: parsed.secret,
      tags: const [],
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(vaultProvider.notifier).saveEntry(newEntry);
      if (mounted) {
        Navigator.pop(context); // Go back to VaultListScreen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save authenticator.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save Authenticator'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title / Account Name *',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _secretController,
                        obscureText: _obscureSecret,
                        decoration: InputDecoration(
                          labelText: 'Authenticator Key (Secret) *',
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureSecret ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                          ),
                        ),
                        onChanged: (val) => setState(() {}), // rebuild to show live preview
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Live Preview',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54),
              ),
              if (_secretController.text.isNotEmpty && TotpUtil.isValidBase32(TotpUtil.parse(_secretController.text).secret))
                TotpDisplay(secret: TotpUtil.parse(_secretController.text).secret)
              else
                Card(
                  margin: const EdgeInsets.only(top: 16),
                  color: Colors.white10,
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Enter a valid secret to see the code', style: TextStyle(color: Colors.white38)),
                    ),
                  ),
                ).animate().fadeIn(),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        ),
      ),
    );
  }
}
