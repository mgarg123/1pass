import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../providers/vault_provider.dart';
import '../../../generator/ui/generator_screen.dart';

class AddEditWifiScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const AddEditWifiScreen({super.key, this.entry});

  @override
  ConsumerState<AddEditWifiScreen> createState() => _AddEditWifiScreenState();
}

class _AddEditWifiScreenState extends ConsumerState<AddEditWifiScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;

  String _securityType = 'WPA/WPA2';
  bool _isHidden = false;
  bool _obscurePassword = true;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const List<String> _securityOptions = [
    'WPA/WPA2',
    'WPA3',
    'WEP',
    'Open / None',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _ssidController = TextEditingController(text: widget.entry?.wifiSsid ?? widget.entry?.title ?? '');
    _passwordController = TextEditingController(text: widget.entry?.wifiPassword ?? widget.entry?.password ?? '');
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
    _tagsController = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
    _securityType = widget.entry?.wifiSecurityType ?? 'WPA/WPA2';
    _isHidden = widget.entry?.wifiIsHidden ?? false;
    _isFavorite = widget.entry?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
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
      setState(() {
        _passwordController.text = generated;
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

    final now = DateTime.now().toUtc();
    DateTime newUpdatedAt = now;
    if (widget.entry != null && !newUpdatedAt.isAfter(widget.entry!.updatedAt)) {
      newUpdatedAt = widget.entry!.updatedAt.add(const Duration(milliseconds: 1));
    }

    final ssid = _ssidController.text.trim();
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : ssid;

    final newEntry = VaultEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      type: EntryType.wifi,
      title: title.isNotEmpty ? title : 'Wi-Fi Network',
      username: '',
      password: _passwordController.text, // keep in password for backward compatibility
      wifiSsid: ssid,
      wifiPassword: _passwordController.text,
      wifiSecurityType: _securityType,
      wifiIsHidden: _isHidden,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      tags: tags,
      isFavorite: _isFavorite,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Wi-Fi network: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Wi-Fi Network?'),
        content: const Text('Are you sure you want to delete this Wi-Fi network?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete Wi-Fi network. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Wi-Fi Network' : 'Edit Wi-Fi Network'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.white70,
            ),
            tooltip: _isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          if (widget.entry != null)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
              // Wi-Fi Details Card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _ssidController,
                        decoration: const InputDecoration(
                          labelText: 'Wi-Fi Network Name (SSID) *',
                          prefixIcon: Icon(Icons.wifi, color: Colors.cyan),
                          hintText: 'e.g. Home_5G, Office_Guest',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Network SSID is required' : null,
                        onChanged: (val) {
                          if (_titleController.text.isEmpty || _titleController.text == val) {
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Wi-Fi Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyan),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              IconButton(
                                icon: const Icon(Icons.casino_outlined, color: Colors.cyan),
                                tooltip: 'Generate Password',
                                onPressed: _openGenerator,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _securityType,
                        decoration: const InputDecoration(
                          labelText: 'Security Type',
                          prefixIcon: Icon(Icons.security, color: Colors.cyan),
                        ),
                        dropdownColor: const Color(0xFF1C1C1E),
                        items: _securityOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _securityType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Hidden Network', style: TextStyle(fontSize: 15)),
                        subtitle: const Text('Check if the SSID is not broadcasted', style: TextStyle(fontSize: 12, color: Colors.white54)),
                        value: _isHidden,
                        activeColor: Colors.cyan,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _isHidden = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Metadata Card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Display Name (optional)',
                          prefixIcon: const Icon(Icons.title),
                          hintText: _ssidController.text.isNotEmpty ? _ssidController.text : 'e.g. Living Room Router',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          prefixIcon: Icon(Icons.label_outline),
                          hintText: 'e.g. home, office, guest',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Router Admin URL',
                          prefixIcon: Icon(Icons.notes),
                          hintText: 'e.g. Router IP: 192.168.1.1, Admin pass: admin123',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ].animate(interval: 50.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
          ),
        ),
      ),
    );
  }
}
