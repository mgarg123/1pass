import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vault_entry.dart';
import '../models/entry_type.dart';
import '../providers/vault_provider.dart';
import '../providers/breach_check_provider.dart';
import '../../generator/ui/generator_screen.dart';
import 'widgets/totp_display.dart';
import '../utils/totp_util.dart';

class AddEditEntryScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const AddEditEntryScreen({super.key, this.entry});

  @override
  ConsumerState<AddEditEntryScreen> createState() => _AddEditEntryScreenState();
}

class _AddEditEntryScreenState extends ConsumerState<AddEditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  late TextEditingController _totpSecretController;

  bool _obscurePassword = true;
  bool _obscureTotpSecret = true;
  String _passwordStrength = '';
  bool _isSaving = false;
  bool _isDeleting = false;

  List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _usernameController = TextEditingController(text: widget.entry?.username ?? '');
    _passwordController = TextEditingController(text: widget.entry?.password ?? '');
    _urlController = TextEditingController(text: widget.entry?.url ?? '');
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
    _tagsController = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
    _totpSecretController = TextEditingController(text: widget.entry?.totpSecret ?? '');
    _customFields = List.from(widget.entry?.customFields ?? []);
    
    _evaluateStrength(_passwordController.text);
  }

  void _evaluateStrength(String value) {
    if (value.isEmpty) {
      _passwordStrength = '';
    } else if (value.length < 8) {
      _passwordStrength = 'Weak';
    } else if (value.length > 16) {
      _passwordStrength = 'Strong';
    } else {
      bool hasLetters = value.contains(RegExp(r'[a-zA-Z]'));
      bool hasNumbers = value.contains(RegExp(r'[0-9]'));
      bool hasSpecial = value.contains(RegExp(r'[^a-zA-Z0-9]'));
      int types = (hasLetters ? 1 : 0) + (hasNumbers ? 1 : 0) + (hasSpecial ? 1 : 0);
      
      if (types < 2) {
        _passwordStrength = 'Weak';
      } else if (value.length >= 12 && types >= 3) {
        _passwordStrength = 'Strong';
      } else {
        _passwordStrength = 'Medium';
      }
    }
    
    // Trigger breach check
    Future.microtask(() {
      ref.read(breachCheckProvider.notifier).checkPassword(value);
    });
    
    setState(() {});
  }

  Future<void> _openGenerator() async {
    final generated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: GeneratorScreen(isStandalone: false),
      ),
    );
    if (generated != null && generated.isNotEmpty) {
      _passwordController.text = generated;
      _evaluateStrength(generated);
    }
  }

  Future<void> _addCustomField() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    bool isObscured = false;

    final result = await showDialog<CustomField>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Custom Field'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Field Name (e.g., PIN)'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  obscureText: isObscured,
                  decoration: const InputDecoration(labelText: 'Field Value'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Hide Value'),
                  contentPadding: EdgeInsets.zero,
                  value: isObscured,
                  onChanged: (val) => setDialogState(() => isObscured = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                    Navigator.pop(ctx, CustomField(name: nameController.text, value: valueController.text, isObscured: isObscured));
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _customFields.add(result);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String? extractedTotpSecret;
    if (_totpSecretController.text.isNotEmpty) {
      final parseResult = TotpUtil.parse(_totpSecretController.text);
      extractedTotpSecret = parseResult.secret;
      if (!TotpUtil.isValidBase32(extractedTotpSecret)) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid TOTP Secret. It must be valid Base32 or an otpauth:// URI.')));
        return;
      }
    }

    final now = DateTime.now().toUtc();
    DateTime newUpdatedAt = now;
    if (widget.entry != null && !newUpdatedAt.isAfter(widget.entry!.updatedAt)) {
      newUpdatedAt = widget.entry!.updatedAt.add(const Duration(milliseconds: 1));
    }

    List<PasswordHistoryItem> history = List.from(widget.entry?.passwordHistory ?? []);
    if (widget.entry != null && widget.entry!.password != _passwordController.text && widget.entry!.password.isNotEmpty) {
      history.insert(0, PasswordHistoryItem(
        password: widget.entry!.password,
        changedAt: now,
      ));
    }

    final newEntry = VaultEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      type: widget.entry?.type ?? EntryType.login,
      title: _titleController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      url: _urlController.text.isEmpty ? null : _urlController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      totpSecret: extractedTotpSecret,
      tags: tags,
      passwordHistory: history,
      customFields: _customFields,
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: newUpdatedAt,
    );

    try {
      await ref.read(vaultProvider.notifier).saveEntry(newEntry);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save entry. Please try again.')));
      }
    }
  }
  
  Future<void> _delete() async {
    if (widget.entry == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await ref.read(vaultProvider.notifier).deleteEntry(widget.entry!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete entry. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final breachState = ref.watch(breachCheckProvider);
    
    String displayStrength = _passwordStrength;
    if (breachState.breachCount > 0 && _passwordController.text.isNotEmpty) {
      displayStrength = 'Compromised';
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Entry' : 'Edit Entry'),
        actions: [
          if (widget.entry != null)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _isSaving ? null : _delete,
                  ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _isDeleting ? null : _save,
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
              if (widget.entry?.totpSecret != null)
                TotpDisplay(secret: widget.entry!.totpSecret!),
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      if (widget.entry?.type != EntryType.authenticator) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username / Email *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: _evaluateStrength,
                          decoration: InputDecoration(
                            labelText: 'Password *',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.entry?.type != EntryType.authenticator) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                displayStrength,
                                style: TextStyle(
                                  color: (displayStrength == 'Weak' || displayStrength == 'Compromised') ? Colors.redAccent
                                      : displayStrength == 'Medium' ? Colors.orangeAccent : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _openGenerator,
                              icon: const Icon(Icons.generating_tokens),
                              label: const Text('Generate'),
                            )
                          ],
                        ),
                        if (breachState.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, left: 12.0),
                            child: Text('Checking breaches...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          )
                        else if (breachState.breachCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Compromised! Found in ${breachState.breachCount} data breaches.',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                          ),
                      ] else ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _totpSecretController,
                          obscureText: _obscureTotpSecret,
                          decoration: InputDecoration(
                            labelText: 'Authenticator Key (Secret) *',
                            prefixIcon: const Icon(Icons.vpn_key),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureTotpSecret ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureTotpSecret = !_obscureTotpSecret),
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.entry?.type != EntryType.authenticator) ...[
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'URL (optional)',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      if (widget.entry?.type != EntryType.authenticator) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _totpSecretController,
                          obscureText: _obscureTotpSecret,
                          decoration: InputDecoration(
                            labelText: 'Authenticator Key (TOTP Secret) (optional)',
                            prefixIcon: const Icon(Icons.access_time),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureTotpSecret ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureTotpSecret = !_obscureTotpSecret),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_customFields.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Custom Fields', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ),
                      ..._customFields.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final field = entry.value;
                        return ListTile(
                          title: Text(field.name),
                          subtitle: Text(field.isObscured ? '••••••••' : field.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _customFields.removeAt(idx);
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _addCustomField,
                icon: const Icon(Icons.add),
                label: const Text('Add Custom Field'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 32),
            ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          ),
        ),
      ),
    );
  }
}
