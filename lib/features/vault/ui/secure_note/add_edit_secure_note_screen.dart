import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../providers/vault_provider.dart';

class AddEditSecureNoteScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const AddEditSecureNoteScreen({super.key, this.entry});

  @override
  ConsumerState<AddEditSecureNoteScreen> createState() => _AddEditSecureNoteScreenState();
}

class _AddEditSecureNoteScreenState extends ConsumerState<AddEditSecureNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;

  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
    _tagsController = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
    _isFavorite = widget.entry?.isFavorite ?? false;
    _customFields = List.from(widget.entry?.customFields ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _notesController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  int get _charCount => _notesController.text.length;

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
      type: EntryType.secureNote,
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Secure Note',
      username: '',
      password: '',
      notes: _notesController.text,
      tags: tags,
      customFields: _customFields,
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
          SnackBar(content: Text('Failed to save secure note: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Secure Note?'),
        content: const Text('Are you sure you want to delete this note? It will be moved to Recently Deleted.'),
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
            const SnackBar(content: Text('Failed to delete note. Please try again.')),
          );
        }
      }
    }
  }

  void _addCustomField() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController();
        final valueController = TextEditingController();
        bool isObscured = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Custom Field'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Field Label (e.g. PIN, Recovery Phrase)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  obscureText: isObscured,
                  decoration: const InputDecoration(labelText: 'Field Value'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Mask / Hide Value'),
                  value: isObscured,
                  onChanged: (val) => setDialogState(() => isObscured = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    setState(() {
                      _customFields.add(CustomField(
                        name: nameController.text.trim(),
                        value: valueController.text,
                        isObscured: isObscured,
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Secure Note' : 'Edit Secure Note'),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.notes, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  '$_wordCount words  •  $_charCount characters',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _addCustomField,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Field', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Note Title *',
                          prefixIcon: Icon(Icons.description_outlined, color: Colors.orange),
                          hintText: 'e.g. Server Recovery Keys, Secret Memo',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          prefixIcon: Icon(Icons.label_outline),
                          hintText: 'e.g. personal, work, keys',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note Body Editor
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'NOTE CONTENT',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 15,
                        minLines: 8,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 15, height: 1.5, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Write your encrypted notes here...\n\nSupports raw text, recovery seeds, configuration tokens, or formatted lists.',
                          alignLabelWithHint: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),

              // Custom Fields Section
              if (_customFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTOM FIELDS',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _customFields.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
                          itemBuilder: (context, idx) {
                            final field = _customFields[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(field.name, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              subtitle: Text(
                                field.isObscured ? '••••••••••••' : field.value,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() => _customFields.removeAt(idx));
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ].animate(interval: 50.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
          ),
        ),
      ),
    );
  }
}
