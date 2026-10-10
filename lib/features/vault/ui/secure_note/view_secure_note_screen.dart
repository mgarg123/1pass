import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';
import '../../../../core/utils/clipboard_util.dart';
import 'add_edit_secure_note_screen.dart';

class ViewSecureNoteScreen extends ConsumerStatefulWidget {
  final VaultEntry entry;

  const ViewSecureNoteScreen({super.key, required this.entry});

  @override
  ConsumerState<ViewSecureNoteScreen> createState() => _ViewSecureNoteScreenState();
}

class _ViewSecureNoteScreenState extends ConsumerState<ViewSecureNoteScreen> {
  final Set<int> _revealedCustomFields = {};

  void _copyToClipboard(String text, String label) {
    ClipboardUtil.copyTemporary(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  int _getWordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(vaultProvider);
    final currentEntry = asyncEntries.value?.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == widget.entry.id,
      orElse: () => null,
    ) ?? widget.entry;

    final noteContent = currentEntry.notes ?? '';
    final words = _getWordCount(noteContent);
    final characters = noteContent.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Note'),
        actions: [
          IconButton(
            icon: Icon(
              currentEntry.isFavorite ? Icons.star : Icons.star_border,
              color: currentEntry.isFavorite ? Colors.amber : Colors.white70,
            ),
            tooltip: currentEntry.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () {
              ref.read(vaultProvider.notifier).toggleFavorite(currentEntry);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Note',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditSecureNoteScreen(entry: currentEntry),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Icon(Icons.description_outlined, color: Colors.orange, size: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentEntry.title,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Secure Note',
                                      style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '$words words • $characters chars',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          tooltip: 'Copy Note',
                          onPressed: noteContent.isEmpty ? null : () => _copyToClipboard(noteContent, 'Note content'),
                        ),
                      ],
                    ),
                    if (currentEntry.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: currentEntry.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note Content Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONTENT',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (noteContent.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _copyToClipboard(noteContent, 'Note content'),
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const Divider(height: 16, color: Colors.white12),
                    const SizedBox(height: 8),
                    SelectableText(
                      noteContent.isNotEmpty ? noteContent : 'This note is empty.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: noteContent.isNotEmpty ? Colors.white : Colors.white38,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Custom Fields Section
            if (currentEntry.customFields.isNotEmpty) ...[
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
                        itemCount: currentEntry.customFields.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, color: Colors.white12),
                        itemBuilder: (context, idx) {
                          final field = currentEntry.customFields[idx];
                          final isRevealed = _revealedCustomFields.contains(idx);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(field.name, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                            subtitle: Text(
                              field.isObscured && !isRevealed ? '••••••••••••' : field.value,
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (field.isObscured)
                                  IconButton(
                                    icon: Icon(isRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        if (isRevealed) {
                                          _revealedCustomFields.remove(idx);
                                        } else {
                                          _revealedCustomFields.add(idx);
                                        }
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.white38, size: 20),
                                  onPressed: () => _copyToClipboard(field.value, field.name),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Metadata Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${DateFormat.yMMMd().format(currentEntry.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    'Updated: ${DateFormat.yMMMd().format(currentEntry.updatedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ].animate(interval: 50.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}
