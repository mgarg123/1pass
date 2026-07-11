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
import 'view_entry_screen.dart';
import 'authenticator/add_authenticator_screen.dart';
import 'credit_card/add_credit_card_screen.dart';
import 'widgets/entry_avatar_widget.dart';
import 'widgets/totp_live_subtitle.dart';
import '../utils/totp_util.dart';
import '../../settings/ui/settings_screen.dart';

enum SortOption { alphabetical, recentlyAdded }

class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  String _searchQuery = '';
  String? _selectedTag;
  bool _showTags = false;
  SortOption _sortOption = SortOption.alphabetical;

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

    final entries = asyncEntries.value ?? [];
    final loginCount = entries.where((e) => e.type == EntryType.login).length;
    final cardCount = entries.where((e) => e.type == EntryType.creditCard).length;
    final totpCount = entries.where((e) => e.type == EntryType.authenticator).length;
    final totalCount = entries.length;

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
        case SyncState.disabled:
          return const Icon(Icons.smartphone, color: Colors.white38, size: 20);
      }
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Row(
            children: [
              const Text('My Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(width: 12),
              buildSyncIcon(),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
          actions: [
            if (syncState == SyncState.failed)
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Retry Sync',
                onPressed: () {
                  ref.read(syncProvider.notifier).triggerSync();
                },
              ),
            IconButton(
              icon: Icon(_showTags ? Icons.filter_alt : Icons.filter_alt_outlined, 
                color: _selectedTag != null ? primaryColor : null),
              tooltip: 'Filter by Tag',
              onPressed: () {
                setState(() => _showTags = !_showTags);
              },
            ),
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort Options',
              onSelected: (option) => setState(() => _sortOption = option),
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: SortOption.alphabetical,
                  checked: _sortOption == SortOption.alphabetical,
                  child: const Text('Alphabetical'),
                ),
                CheckedPopupMenuItem(
                  value: SortOption.recentlyAdded,
                  checked: _sortOption == SortOption.recentlyAdded,
                  child: const Text('Recently Added'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock Vault',
              onPressed: () {
                ref.read(authProvider.notifier).lockVault();
              },
            )
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.white54, size: 20),
                        prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 36),
                        hintText: 'Search vault...',
                        hintStyle: TextStyle(color: Colors.white54, fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.2),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: primaryColor,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: 'All ($totalCount)'),
                    Tab(text: 'Logins ($loginCount)'),
                    Tab(text: 'Cards ($cardCount)'),
                    Tab(text: '2FA ($totpCount)'),
                  ],
                ),
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
              child: RefreshIndicator(
                color: primaryColor,
                backgroundColor: const Color(0xFF1C1C1E),
                onRefresh: () async {
                  ref.read(syncProvider.notifier).triggerSync();
                  // Small delay to let sync start and show indicator
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: asyncEntries.when(
                  loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
                  error: (err, st) => ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))))]),
                  data: (dataEntries) {
                    if (dataEntries.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined, size: 80, color: primaryColor.withOpacity(0.5))
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
                          ),
                        ],
                      );
                    }

                    return TabBarView(
                      children: [
                        _buildTabContent(context, dataEntries, null, primaryColor),
                        _buildTabContent(context, dataEntries, EntryType.login, primaryColor),
                        _buildTabContent(context, dataEntries, EntryType.creditCard, primaryColor),
                        _buildTabContent(context, dataEntries, EntryType.authenticator, primaryColor),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF1C1C1E),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('Add Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                    title: const Text('Login / Password'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditEntryScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Colors.black26),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                    title: const Text('Authenticator (2FA)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddAuthenticatorScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Colors.black26),
                  ListTile(
                    leading: const Icon(Icons.credit_card, color: Colors.blueAccent),
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
    List<VaultEntry> filtered = entries.where((e) {
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

    if (_sortOption == SortOption.recentlyAdded) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      // Default alphabetical (already handled in provider, but re-sort just in case search messes it up)
      filtered.sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.white24),
                const SizedBox(height: 24),
                Text(
                  'No results for "$_searchQuery"',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try adjusting your search or filters.',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ).animate().fadeIn(),
          ),
        ],
      );
    } else if (filtered.isEmpty) {
      return ListView(); // Empty tab state (e.g. no cards added yet)
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Dismissible(
              key: Key(entry.id),
              direction: DismissDirection.horizontal,
              background: Container(
                color: Colors.blueAccent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                child: const Icon(Icons.copy, color: Colors.white),
              ),
              secondaryBackground: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Swipe Right -> Copy
                  if (entry.type == EntryType.login) {
                    _copyToClipboard(entry.password, 'Password');
                  } else if (entry.type == EntryType.authenticator && entry.totpSecret != null) {
                    final code = TotpUtil.generateCode(entry.totpSecret!);
                    _copyToClipboard(code, '2FA Code');
                  } else if (entry.type == EntryType.creditCard && entry.cardNumber != null) {
                    _copyToClipboard(entry.cardNumber!, 'Card Number');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nothing to copy')),
                    );
                  }
                  return false; // Snap back, don't dismiss
                } else {
                  // Swipe Left -> Delete
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Entry?'),
                      content: Text('Are you sure you want to delete "${entry.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(vaultProvider.notifier).deleteEntry(entry.id);
                    return true;
                  }
                  return false;
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: entry.isFavorite ? primaryColor.withOpacity(0.1) : const Color(0xFF1C1C1E),
                  border: entry.isFavorite ? Border.all(color: primaryColor.withOpacity(0.3), width: 1) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onLongPress: () async {
                    await ref.read(vaultProvider.notifier).toggleFavorite(entry);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(entry.isFavorite ? 'Removed from favorites' : 'Added to favorites'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) {
                          if (entry.type == EntryType.creditCard) {
                            return AddCreditCardScreen(entry: entry);
                          } else if (entry.type == EntryType.login) {
                            return ViewEntryScreen(entry: entry);
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
              ),
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
                  selectedColor: primaryColor.withOpacity(0.5),
                  backgroundColor: const Color(0xFF1C1C1E),
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
