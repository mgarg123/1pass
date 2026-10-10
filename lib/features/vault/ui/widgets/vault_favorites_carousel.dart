import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../utils/totp_util.dart';
import 'entry_avatar_widget.dart';

class VaultFavoritesCarousel extends StatelessWidget {
  final List<VaultEntry> favorites;
  final ValueChanged<VaultEntry> onItemTap;
  final void Function(String text, String label) onCopy;

  const VaultFavoritesCarousel({
    super.key,
    required this.favorites,
    required this.onItemTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 6),
              const Text(
                'FAVORITES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${favorites.length}',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final entry = favorites[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onItemTap(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              EntryAvatarWidget(entry: entry, size: 34),
                              _buildQuickCopyButton(entry),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getCardSubtitle(entry),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuickCopyButton(VaultEntry entry) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        if (entry.type == EntryType.login && entry.password.isNotEmpty) {
          onCopy(entry.password, 'Password');
        } else if (entry.type == EntryType.authenticator && entry.totpSecret != null) {
          final code = TotpUtil.generateCode(entry.totpSecret!);
          onCopy(code, '2FA Code');
        } else if (entry.type == EntryType.creditCard && entry.cardNumber != null) {
          onCopy(entry.cardNumber!, 'Card Number');
        } else if (entry.type == EntryType.wifi) {
          onCopy(entry.wifiPassword ?? entry.password, 'Wi-Fi Password');
        } else if (entry.type == EntryType.secureNote && entry.notes != null) {
          onCopy(entry.notes!, 'Note');
        } else {
          onCopy(entry.username, 'Username');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.copy, size: 14, color: Colors.white70),
      ),
    );
  }

  String _getCardSubtitle(VaultEntry entry) {
    switch (entry.type) {
      case EntryType.creditCard:
        final clean = (entry.cardNumber ?? '').replaceAll(RegExp(r'\s+'), '');
        return clean.length >= 4 ? '•••• ${clean.substring(clean.length - 4)}' : 'Card';
      case EntryType.authenticator:
        return entry.totpSecret != null ? '2FA Token' : 'Authenticator';
      case EntryType.wifi:
        return entry.wifiSsid ?? 'Wi-Fi';
      case EntryType.secureNote:
        return 'Private Note';
      case EntryType.identity:
        return entry.identityEmail ?? 'Profile';
      case EntryType.login:
      default:
        return entry.username.isNotEmpty ? entry.username : 'Login';
    }
  }
}
