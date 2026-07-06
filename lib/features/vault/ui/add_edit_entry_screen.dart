import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vault_entry.dart';
import '../providers/vault_provider.dart';
import '../providers/breach_check_provider.dart';
import '../../generator/ui/generator_screen.dart';

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

  bool _obscurePassword = true;
  String _passwordStrength = '';
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _usernameController = TextEditingController(text: widget.entry?.username ?? '');
    _passwordController = TextEditingController(text: widget.entry?.password ?? '');
    _urlController = TextEditingController(text: widget.entry?.url ?? '');
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
    _tagsController = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
    
    _evaluateStrength(_passwordController.text);
  }

  void _evaluateStrength(String value) {
    if (value.isEmpty) {
      _passwordStrength = '';
    } else if (value.length < 8) {
      _passwordStrength = 'Weak';
    } else if (value.length < 12) {
      _passwordStrength = 'Medium';
    } else {
      _passwordStrength = 'Strong';
    }
    
    // Trigger breach check
    Future.microtask(() {
      ref.read(breachCheckProvider.notifier).checkPassword(value);
    });
    
    setState(() {});
  }

  Future<void> _openGenerator() async {
    final generated = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GeneratorScreen()),
    );
    if (generated != null && generated.isNotEmpty) {
      _passwordController.text = generated;
      _evaluateStrength(generated);
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

    final now = DateTime.now().toUtc();
    DateTime newUpdatedAt = now;
    if (widget.entry != null && !newUpdatedAt.isAfter(widget.entry!.updatedAt)) {
      newUpdatedAt = widget.entry!.updatedAt.add(const Duration(milliseconds: 1));
    }

    final newEntry = VaultEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      title: _titleController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      url: _urlController.text.isEmpty ? null : _urlController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      tags: tags,
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
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'URL (optional)',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
              ),
            ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          ),
        ),
      ),
    );
  }
}
