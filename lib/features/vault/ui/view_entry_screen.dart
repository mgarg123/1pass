import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vault_entry.dart';
import '../providers/vault_provider.dart';
import '../../../core/utils/clipboard_util.dart';
import 'widgets/entry_avatar_widget.dart';
import 'add_edit_entry_screen.dart';
import 'widgets/totp_live_subtitle.dart';
import '../utils/totp_util.dart';

class ViewEntryScreen extends ConsumerWidget {
  final VaultEntry entry;

  const ViewEntryScreen({super.key, required this.entry});

  void _copyToClipboard(BuildContext context, String text, String label) {
    ClipboardUtil.copyTemporary(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    try {
      var uriStr = urlString.trim();
      if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
        uriStr = 'https://$uriStr';
      }
      final uri = Uri.parse(uriStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(vaultProvider);
    final currentEntry = asyncEntries.value?.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == entry.id,
      orElse: () => null,
    ) ?? entry;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditEntryScreen(entry: currentEntry),
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
            Center(
              child: Column(
                children: [
                  Transform.scale(
                    scale: 1.5,
                    child: EntryAvatarWidget(entry: currentEntry),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    currentEntry.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (currentEntry.url != null && currentEntry.url!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _launchUrl(context, currentEntry.url!),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_new, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                currentEntry.url!,
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            const Text(
              'CREDENTIALS',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  if (currentEntry.username.isNotEmpty) ...[
                    ListTile(
                      title: const Text('Username', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      subtitle: Text(currentEntry.username, style: const TextStyle(fontSize: 16, color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white38),
                        onPressed: () => _copyToClipboard(context, currentEntry.username, 'Username'),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, color: Colors.white12),
                  ],
                  if (currentEntry.password.isNotEmpty) ...[
                    ListTile(
                      title: const Text('Password', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      subtitle: const Text('••••••••••••', style: TextStyle(fontSize: 16, color: Colors.white, letterSpacing: 2)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white38),
                        onPressed: () => _copyToClipboard(context, currentEntry.password, 'Password'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            if (currentEntry.totpSecret != null && currentEntry.totpSecret!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'SECURITY',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: const Text('One-Time Password', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: TotpLiveSubtitle(secret: currentEntry.totpSecret!),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white38),
                    onPressed: () {
                      final code = TotpUtil.generateCode(currentEntry.totpSecret!);
                      _copyToClipboard(context, code, '2FA Code');
                    },
                  ),
                ),
              ),
            ],

            if ((currentEntry.notes != null && currentEntry.notes!.isNotEmpty) || currentEntry.tags.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'ADDITIONAL DETAILS',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (currentEntry.tags.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tags', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentEntry.tags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(tag, style: const TextStyle(fontSize: 12)),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      if (currentEntry.notes != null && currentEntry.notes!.isNotEmpty)
                        const Divider(height: 1, indent: 16, color: Colors.white12),
                    ],
                    if (currentEntry.notes != null && currentEntry.notes!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notes', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(currentEntry.notes!, style: const TextStyle(fontSize: 16, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
