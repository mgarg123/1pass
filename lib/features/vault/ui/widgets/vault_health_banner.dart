import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/password_health_provider.dart';
import '../password_health_screen.dart';

class VaultHealthBanner extends ConsumerStatefulWidget {
  const VaultHealthBanner({super.key});

  @override
  ConsumerState<VaultHealthBanner> createState() => _VaultHealthBannerState();
}

class _VaultHealthBannerState extends ConsumerState<VaultHealthBanner> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final healthAsync = ref.watch(passwordHealthProvider);

    return healthAsync.maybeWhen(
      data: (healthState) {
        final warningItems = healthState.items.where((i) => i.hasWarnings).toList();
        if (warningItems.isEmpty) return const SizedBox.shrink();

        final pwnedCount = warningItems.where((i) => i.warnings.contains('pwned')).length;
        final weakCount = warningItems.where((i) => i.warnings.contains('weak')).length;
        final reusedCount = warningItems.where((i) => i.warnings.contains('reused')).length;

        final isUrgent = pwnedCount > 0;
        final accentColor = isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

        String subtitle = '';
        if (pwnedCount > 0) {
          subtitle = '$pwnedCount compromised password${pwnedCount > 1 ? 's' : ''}';
        } else if (weakCount > 0 && reusedCount > 0) {
          subtitle = '$weakCount weak, $reusedCount reused passwords';
        } else if (weakCount > 0) {
          subtitle = '$weakCount weak password${weakCount > 1 ? 's' : ''}';
        } else {
          subtitle = '${warningItems.length} items need attention';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.15),
                const Color(0xFF1C1C1E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PasswordHealthScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isUrgent ? Icons.warning_amber_rounded : Icons.shield_outlined,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUrgent ? 'Security Breach Alert' : 'Vault Health Recommendation',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Review',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _isDismissed = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
