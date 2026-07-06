import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vault_provider.dart';
import '../models/entry_type.dart';
import '../models/vault_entry.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/utils/clipboard_util.dart';
import 'add_edit_entry_screen.dart';
import 'authenticator/add_authenticator_screen.dart';
import 'credit_card/add_credit_card_screen.dart';
import 'widgets/entry_avatar_widget.dart';
import 'widgets/totp_live_subtitle.dart';
import '../utils/totp_util.dart';
import '../../settings/ui/settings_screen.dart';

class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  String _searchQuery = '';
  String? _selectedTag;
  bool _showTags = false;
  bool _isSearching = false;

  void _copyToClipboard(String text, String label) {
    ClipboardUtil.copyTemporary(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  void dispose() {
    ClipboardUtil.cancelTimer();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(vaultProvider);
    final syncState = ref.watch(syncProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    Widget buildSyncIcon() {
      switch (syncState) {
        case SyncState.synced:
          return const Icon(Icons.cloud_done, color: Colors.greenAccent, size: 20);
        case SyncState.syncing:
          return SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          );
        case SyncState.offline:
          return const Icon(Icons.cloud_off, color: Colors.white38, size: 20);
        case SyncState.failed:
          return const Icon(Icons.cloud_off, color: Colors.redAccent, size: 20);
      }
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
        title: _isSearching
            ? SizedBox(
                height: 40,
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search vault...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 16),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ).animate().fadeIn(duration: 200.ms)
            : Row(
                children: [
                  const Text('My Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  buildSyncIcon(),
                ],
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (syncState == SyncState.failed && !_isSearching)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Retry Sync',
              onPressed: () {
                ref.read(syncProvider.notifier).triggerSync();
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: Icon(_showTags ? Icons.filter_alt : Icons.filter_alt_outlined, 
                color: _selectedTag != null ? Theme.of(context).primaryColor : null),
              tooltip: 'Filter by Tag',
              onPressed: () {
                setState(() => _showTags = !_showTags);
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock Vault',
              onPressed: () {
                ref.read(authProvider.notifier).lockVault();
              },
            )
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Logins'),
              Tab(text: 'Cards'),
              Tab(text: '2FA'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showTags ? _buildTagsRow(asyncEntries, primaryColor) : const SizedBox(width: double.infinity, height: 0),
          ),
          Expanded(
            child: asyncEntries.when(
        loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
        error: (err, st) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 80, color: primaryColor.withValues(alpha: 0.5))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: -5, end: 5, duration: 2.seconds),
                  const SizedBox(height: 24),
                  Text(
                    'Your vault is empty',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 24),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to add your first password.',
                    style: TextStyle(color: Colors.white54),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            );
          }

          return TabBarView(
            children: [
              _buildTabContent(context, entries, null, primaryColor),
              _buildTabContent(context, entries, EntryType.login, primaryColor),
              _buildTabContent(context, entries, EntryType.creditCard, primaryColor),
              _buildTabContent(context, entries, EntryType.authenticator, primaryColor),
            ],
          );
        },
      ),
      ),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Add Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Login / Password'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEditEntryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Authenticator (2FA)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAuthenticatorScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Credit Card'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddCreditCardScreen()),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, List<VaultEntry> entries, EntryType? filterType, Color primaryColor) {
    final filtered = entries.where((e) {
      if (filterType != null && e.type != filterType) return false;
      final q = _searchQuery;
      final matchesSearch = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          (e.bankName?.toLowerCase().contains(q) ?? false) ||
          (e.cardholderName?.toLowerCase().contains(q) ?? false) ||
          (e.cardNumber?.replaceAll(RegExp(r'\s+'), '').contains(q) ?? false) ||
          (e.notes?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchesTag = _selectedTag == null || e.tags.contains(_selectedTag);
      return matchesSearch && matchesTag;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white24),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Proper horizontal padding and FAB space
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    if (entry.type == EntryType.creditCard) {
                      return AddCreditCardScreen(entry: entry);
                    }
                    return AddEditEntryScreen(entry: entry);
                  },
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: EntryAvatarWidget(entry: entry),
                title: Text(
                  entry.type == EntryType.creditCard && entry.bankName != null && entry.bankName!.isNotEmpty
                      ? '${entry.bankName} - ${entry.title}'
                      : entry.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: entry.type == EntryType.authenticator 
                  ? (entry.totpSecret != null ? TotpLiveSubtitle(secret: entry.totpSecret!) : const Text('Authenticator', style: TextStyle(color: Colors.white54)))
                  : Text(
                      entry.type == EntryType.creditCard ? (entry.cardNumber != null && entry.cardNumber!.replaceAll(RegExp(r'\s+'), '').length >= 4 ? '•••• ${entry.cardNumber!.replaceAll(RegExp(r'\s+'), '').substring(entry.cardNumber!.replaceAll(RegExp(r'\s+'), '').length - 4)}' : 'Credit Card')
                      : entry.username, 
                      style: const TextStyle(color: Colors.white54)
                    ),
                trailing: entry.type == EntryType.login 
                    ? IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white38),
                        tooltip: 'Copy Password',
                        onPressed: () => _copyToClipboard(entry.password, 'Password'),
                      )
                    : entry.type == EntryType.authenticator && entry.totpSecret != null
                        ? IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white38),
                            tooltip: 'Copy 2FA Code',
                            onPressed: () {
                              final code = TotpUtil.generateCode(entry.totpSecret!);
                              _copyToClipboard(code, '2FA Code');
                            },
                          )
                        : const Icon(Icons.chevron_right, color: Colors.white38),
              ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildTagsRow(AsyncValue<List<VaultEntry>> asyncEntries, Color primaryColor) {
    return asyncEntries.maybeWhen(
      data: (entries) {
        final allTags = entries.expand((e) => e.tags).toSet().toList()..sort();
        if (allTags.isEmpty) return const SizedBox.shrink();
        
        return Container(
          height: 52,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
            color: Colors.black12,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allTags.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.local_offer_outlined, color: Colors.white38, size: 18),
                );
              }
              final tag = allTags[index - 1];
              final isSelected = _selectedTag == tag;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white70)),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: primaryColor.withValues(alpha: 0.5),
                  backgroundColor: Theme.of(context).cardColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? primaryColor : Colors.white12),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTag = selected ? tag : null;
                    });
                  },
                ),
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

