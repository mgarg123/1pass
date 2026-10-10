import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VaultCategoryPill {
  final String key;
  final String label;
  final IconData icon;

  const VaultCategoryPill({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class VaultCategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final Map<String, int> counts;

  static const List<VaultCategoryPill> categories = [
    VaultCategoryPill(key: 'all', label: 'All', icon: Icons.grid_view_rounded),
    VaultCategoryPill(key: 'login', label: 'Logins', icon: Icons.lock_outline),
    VaultCategoryPill(key: 'note', label: 'Notes', icon: Icons.description_outlined),
    VaultCategoryPill(key: 'card', label: 'Cards', icon: Icons.credit_card),
    VaultCategoryPill(key: 'wifi', label: 'Wi-Fi', icon: Icons.wifi),
    VaultCategoryPill(key: 'identity', label: 'Identities', icon: Icons.badge_outlined),
    VaultCategoryPill(key: 'totp', label: '2FA', icon: Icons.access_time),
    VaultCategoryPill(key: 'passkey', label: 'Passkeys', icon: Icons.key),
  ];

  const VaultCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final visibleCategories = categories.where((cat) {
      if (cat.key == 'all') return true;
      final count = counts[cat.key] ?? 0;
      return count > 0;
    }).toList();

    // If only 'All' has items and no subcategories, or no items at all, don't show empty pill bar
    if (visibleCategories.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: visibleCategories.length,
        itemBuilder: (context, index) {
          final cat = visibleCategories[index];
          final isSelected = selectedCategory == cat.key;
          final count = counts[cat.key] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onCategorySelected(cat.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withValues(alpha: 0.22) : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? primaryColor : const Color(0xFF2C2C2E),
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected ? primaryColor : Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
