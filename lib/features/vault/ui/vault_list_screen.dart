import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'credit_card/add_credit_card_screen.dart';
import 'secure_note/view_secure_note_screen.dart';
import 'wifi/view_wifi_screen.dart';
import 'identity/view_identity_screen.dart';
import 'widgets/entry_avatar_widget.dart';
import 'widgets/totp_live_subtitle.dart';
import 'widgets/vault_health_banner.dart';
import 'widgets/vault_favorites_carousel.dart';
import 'widgets/vault_category_chips.dart';
import 'widgets/add_item_sheet.dart';
import '../utils/totp_util.dart';
import '../../settings/ui/settings_screen.dart';

enum SortOption { alphabetical, recentlyAdded }

class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;
  bool _showTags = false;
  String _selectedCategory = 'all';
  SortOption _sortOption = SortOption.alphabetical;

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    ClipboardUtil.copyTemporary(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _showSortBottomSheet() {
    HapticFeedback.lightImpact();
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Sort Vault Items',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOptionTile(
                title: 'Alphabetical (A → Z)',
                subtitle: 'Grouped by letter with favorites pinned',
                icon: Icons.sort_by_alpha_rounded,
                isSelected: _sortOption == SortOption.alphabetical,
                onTap: () {
                  setState(() => _sortOption = SortOption.alphabetical);
                  Navigator.pop(ctx);
                },
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
              _buildSortOptionTile(
                title: 'Recently Added',
                subtitle: 'Newest entries shown first',
                icon: Icons.access_time_rounded,
                isSelected: _sortOption == SortOption.recentlyAdded,
                onTap: () {
                  setState(() => _sortOption = SortOption.recentlyAdded);
                  Navigator.pop(ctx);
                },
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: 0.15) : const Color(0xFF242428),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.06),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? primaryColor : Colors.white60, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final noteCount = entries.where((e) => e.type == EntryType.secureNote).length;
    final cardCount = entries.where((e) => e.type == EntryType.creditCard).length;
    final wifiCount = entries.where((e) => e.type == EntryType.wifi).length;
    final identityCount = entries.where((e) => e.type == EntryType.identity).length;
    final totpCount = entries.where((e) => e.type == EntryType.authenticator).length;
    final passkeyCount = entries.where((e) => e.passkeyPrivateKey != null && e.passkeyPrivateKey!.isNotEmpty).length;
    final totalCount = entries.length;

    final counts = {
      'all': totalCount,
      'login': loginCount,
      'note': noteCount,
      'card': cardCount,
      'wifi': wifiCount,
      'identity': identityCount,
      'totp': totpCount,
      'passkey': passkeyCount,
    };

    final effectiveCategory = (_selectedCategory != 'all' && (counts[_selectedCategory] ?? 0) == 0)
        ? 'all'
        : _selectedCategory;

    final favorites = entries.where((e) => e.isFavorite).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'My Vault',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            _buildSyncIndicator(syncState, primaryColor),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
            tooltip: 'Settings',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.white70, size: 22),
            tooltip: 'Lock Vault',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(authProvider.notifier).lockVault();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Input ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchQuery.isNotEmpty ? primaryColor.withValues(alpha: 0.5) : const Color(0xFF2C2C2E),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search vault...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                      visualDensity: VisualDensity.compact,
                      onPressed: _clearSearch,
                    ),
                  IconButton(
                    icon: Icon(
                      _showTags ? Icons.label : Icons.label_outline,
                      color: _selectedTag != null ? primaryColor : Colors.white60,
                      size: 20,
                    ),
                    tooltip: 'Filter by Tag',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showTags = !_showTags);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.swap_vert_rounded,
                      color: _sortOption == SortOption.recentlyAdded ? primaryColor : Colors.white60,
                      size: 22,
                    ),
                    tooltip: 'Sort Items',
                    visualDensity: VisualDensity.compact,
                    onPressed: _showSortBottomSheet,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // ── Expandable Tag Bar ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showTags ? _buildTagsBar(entries, primaryColor) : const SizedBox.shrink(),
          ),

          // ── Main Body with Pull to Refresh ──
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              backgroundColor: const Color(0xFF1C1C1E),
              onRefresh: () async {
                ref.read(syncProvider.notifier).triggerSync();
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: asyncEntries.when(
                loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
                error: (err, st) => ListView(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Error loading vault: $err', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ],
                ),
                data: (allEntries) {
                  if (allEntries.isEmpty) {
                    return _buildEmptyVaultState(primaryColor);
                  }

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      // 1. Vault Health Banner
                      if (_searchQuery.isEmpty)
                        const SliverToBoxAdapter(child: VaultHealthBanner()),

                      // 2. Favorites Carousel
                      if (_searchQuery.isEmpty && _selectedCategory == 'all' && favorites.isNotEmpty)
                        SliverToBoxAdapter(
                          child: VaultFavoritesCarousel(
                            favorites: favorites,
                            onItemTap: _navigateToDetail,
                            onCopy: _copyToClipboard,
                          ),
                        ),

                      // 3. Category Filter Chips
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: VaultCategoryChips(
                            selectedCategory: effectiveCategory,
                            onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                            counts: counts,
                          ),
                        ),
                      ),

                      // 4. Grouped or Flat Item List
                      _buildItemsSliver(allEntries, primaryColor, effectiveCategory),

                      // Bottom spacing for FAB
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 90),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddItemSheet.show(context),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
        ),
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildSyncIndicator(SyncState syncState, Color primaryColor) {
    switch (syncState) {
      case SyncState.synced:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 14),
              SizedBox(width: 4),
              Text('Synced', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case SyncState.syncing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
        );
      case SyncState.failed:
        return InkWell(
          onTap: () => ref.read(syncProvider.notifier).triggerSync(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_problem_rounded, color: Colors.redAccent, size: 14),
                SizedBox(width: 4),
                Text('Retry', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      case SyncState.offline:
      case SyncState.disabled:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTagsBar(List<VaultEntry> entries, Color primaryColor) {
    final allTags = entries.expand((e) => e.tags).toSet().toList()..sort();
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allTags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 16, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      'Tags (${allTags.length}):',
                      style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }
          final tag = allTags[index - 1];
          final isSelected = _selectedTag == tag;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white70)),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: primaryColor.withValues(alpha: 0.4),
              backgroundColor: const Color(0xFF1C1C1E),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? primaryColor : Colors.white12),
              ),
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() => _selectedTag = selected ? tag : null);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsSliver(List<VaultEntry> allEntries, Color primaryColor, String category) {
    final filtered = allEntries.where((e) {
      if (category == 'login' && e.type != EntryType.login) return false;
      if (category == 'note' && e.type != EntryType.secureNote) return false;
      if (category == 'card' && e.type != EntryType.creditCard) return false;
      if (category == 'wifi' && e.type != EntryType.wifi) return false;
      if (category == 'identity' && e.type != EntryType.identity) return false;
      if (category == 'totp' && e.type != EntryType.authenticator) return false;
      if (category == 'passkey' && (e.passkeyPrivateKey == null || e.passkeyPrivateKey!.isEmpty)) return false;

      final q = _searchQuery;
      final matchesSearch = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          (e.wifiSsid?.toLowerCase().contains(q) ?? false) ||
          (e.identityFirstName?.toLowerCase().contains(q) ?? false) ||
          (e.identityLastName?.toLowerCase().contains(q) ?? false) ||
          (e.identityEmail?.toLowerCase().contains(q) ?? false) ||
          (e.identityCompany?.toLowerCase().contains(q) ?? false) ||
          (e.bankName?.toLowerCase().contains(q) ?? false) ||
          (e.cardholderName?.toLowerCase().contains(q) ?? false) ||
          (e.cardNumber?.replaceAll(RegExp(r'\s+'), '').contains(q) ?? false) ||
          (e.notes?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchesTag = _selectedTag == null || e.tags.contains(_selectedTag);
      return matchesSearch && matchesTag;
    }).toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 56, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No items found for "$_searchQuery"' : 'No items in this category',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting your search terms or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear Search'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Sorting
    if (_sortOption == SortOption.recentlyAdded) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    // When searching or when recently-added sorting is active, render flat list with cards
    if (_searchQuery.isNotEmpty || _sortOption == SortOption.recentlyAdded) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = filtered[index];
              return _buildItemCard(entry, primaryColor);
            },
            childCount: filtered.length,
          ),
        ),
      );
    }

    // Alphabetical Grouping (A, B, C...)
    final Map<String, List<VaultEntry>> groups = {};
    for (final entry in filtered) {
      final firstChar = entry.title.trim().isNotEmpty
          ? entry.title.trim()[0].toUpperCase()
          : '#';
      final groupKey = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      groups.putIfAbsent(groupKey, () => []).add(entry);
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final key = sortedKeys[index];
            final groupEntries = groups[key]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
                  child: Text(
                    '$key (${groupEntries.length})',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161618),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: List.generate(groupEntries.length, (i) {
                        final entry = groupEntries[i];
                        return Column(
                          children: [
                            _buildGroupItemRow(entry, primaryColor),
                            if (i < groupEntries.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.6,
                                indent: 64,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            );
          },
          childCount: sortedKeys.length,
        ),
      ),
    );
  }

  Widget _buildGroupItemRow(VaultEntry entry, Color primaryColor) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: const Color(0xFF2563EB),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.copy, color: Colors.white, size: 20),
      ),
      secondaryBackground: Container(
        color: const Color(0xFFDC2626),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      confirmDismiss: (direction) => _handleDismiss(direction, entry),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(entry),
          onLongPress: () => _toggleFavorite(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                EntryAvatarWidget(entry: entry, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.type == EntryType.creditCard && entry.bankName != null && entry.bankName!.isNotEmpty
                                  ? '${entry.bankName} - ${entry.title}'
                                  : entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (entry.isFavorite) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFBBF24)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      _buildSubtitle(entry),
                    ],
                  ),
                ),
                _buildTrailingAction(entry),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(VaultEntry entry, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.horizontal,
          background: Container(
            color: const Color(0xFF2563EB),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.copy, color: Colors.white, size: 20),
          ),
          secondaryBackground: Container(
            color: const Color(0xFFDC2626),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          ),
          confirmDismiss: (direction) => _handleDismiss(direction, entry),
          child: Container(
            decoration: BoxDecoration(
              color: entry.isFavorite ? primaryColor.withValues(alpha: 0.1) : const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: entry.isFavorite ? primaryColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.07),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _navigateToDetail(entry),
                onLongPress: () => _toggleFavorite(entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      EntryAvatarWidget(entry: entry, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
                                  ),
                                ),
                                if (entry.isFavorite) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFBBF24)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            _buildSubtitle(entry),
                          ],
                        ),
                      ),
                      _buildTrailingAction(entry),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _handleDismiss(DismissDirection direction, VaultEntry entry) async {
    if (direction == DismissDirection.startToEnd) {
      if (entry.type == EntryType.login && entry.password.isNotEmpty) {
        _copyToClipboard(entry.password, 'Password');
      } else if (entry.type == EntryType.authenticator && entry.totpSecret != null) {
        final code = TotpUtil.generateCode(entry.totpSecret!);
        _copyToClipboard(code, '2FA Code');
      } else if (entry.type == EntryType.creditCard && entry.cardNumber != null) {
        _copyToClipboard(entry.cardNumber!, 'Card Number');
      } else if (entry.type == EntryType.wifi) {
        _copyToClipboard(entry.wifiPassword ?? entry.password, 'Wi-Fi Password');
      } else if (entry.type == EntryType.secureNote && entry.notes != null) {
        _copyToClipboard(entry.notes!, 'Note');
      } else {
        _copyToClipboard(entry.username, 'Username');
      }
      return false;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Delete Entry?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${entry.title}"?'),
              const SizedBox(height: 10),
              const Text(
                'It can be restored from Settings > Recently Deleted within 30 days.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
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
  }

  void _navigateToDetail(VaultEntry entry) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          switch (entry.type) {
            case EntryType.creditCard:
              return AddCreditCardScreen(entry: entry);
            case EntryType.login:
              return ViewEntryScreen(entry: entry);
            case EntryType.secureNote:
              return ViewSecureNoteScreen(entry: entry);
            case EntryType.wifi:
              return ViewWifiScreen(entry: entry);
            case EntryType.identity:
              return ViewIdentityScreen(entry: entry);
            case EntryType.authenticator:
              return ViewEntryScreen(entry: entry);
            default:
              return AddEditEntryScreen(entry: entry);
          }
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    HapticFeedback.lightImpact();
    await ref.read(vaultProvider.notifier).toggleFavorite(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(entry.isFavorite ? 'Removed from favorites' : 'Added to favorites'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSubtitle(VaultEntry entry) {
    switch (entry.type) {
      case EntryType.authenticator:
        return entry.totpSecret != null
            ? TotpLiveSubtitle(secret: entry.totpSecret!)
            : const Text('Authenticator', style: TextStyle(color: Colors.white54, fontSize: 13));
      case EntryType.creditCard:
        final clean = (entry.cardNumber ?? '').replaceAll(RegExp(r'\s+'), '');
        return Text(
          clean.length >= 4 ? '•••• ${clean.substring(clean.length - 4)}' : 'Credit Card',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        );
      case EntryType.secureNote:
        final noteFirstLine = (entry.notes ?? '').split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Secure Note');
        return Text(
          noteFirstLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        );
      case EntryType.wifi:
        return Text(
          entry.wifiSecurityType ?? 'Wi-Fi Network',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        );
      case EntryType.identity:
        final detail = [entry.identityOccupation, entry.identityCompany].where((s) => s != null && s.isNotEmpty).join(' • ');
        return Text(
          detail.isNotEmpty ? detail : (entry.identityEmail ?? 'Identity Profile'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        );
      case EntryType.login:
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(entry.username, style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis)),
            if (entry.passkeyPrivateKey != null && entry.passkeyPrivateKey!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Row(
                  children: [
                    Icon(Icons.key, size: 10, color: Colors.blueAccent),
                    SizedBox(width: 3),
                    Text('Passkey', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildTrailingAction(VaultEntry entry) {
    if (entry.type == EntryType.login && entry.password.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
        tooltip: 'Copy Password',
        visualDensity: VisualDensity.compact,
        onPressed: () => _copyToClipboard(entry.password, 'Password'),
      );
    } else if (entry.type == EntryType.wifi && (entry.wifiPassword != null || entry.password.isNotEmpty)) {
      final p = entry.wifiPassword ?? entry.password;
      return IconButton(
        icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
        tooltip: 'Copy Wi-Fi Password',
        visualDensity: VisualDensity.compact,
        onPressed: () => _copyToClipboard(p, 'Wi-Fi Password'),
      );
    } else if (entry.type == EntryType.secureNote && entry.notes != null && entry.notes!.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
        tooltip: 'Copy Note',
        visualDensity: VisualDensity.compact,
        onPressed: () => _copyToClipboard(entry.notes!, 'Note content'),
      );
    } else if (entry.type == EntryType.authenticator && entry.totpSecret != null) {
      return IconButton(
        icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
        tooltip: 'Copy 2FA Code',
        visualDensity: VisualDensity.compact,
        onPressed: () {
          final code = TotpUtil.generateCode(entry.totpSecret!);
          _copyToClipboard(code, '2FA Code');
        },
      );
    }
    return const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20);
  }

  Widget _buildEmptyVaultState(Color primaryColor) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Icon(Icons.shield_outlined, size: 64, color: primaryColor)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: -4, end: 4, duration: 2.seconds),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Vault is Empty',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Securely store passwords, notes, credit cards, Wi-Fi keys, and 2FA codes with zero-knowledge encryption.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => AddItemSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Your First Item', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
