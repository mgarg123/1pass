import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../add_edit_entry_screen.dart';
import '../authenticator/add_authenticator_screen.dart';
import '../credit_card/add_credit_card_screen.dart';
import '../secure_note/add_edit_secure_note_screen.dart';
import '../wifi/add_edit_wifi_screen.dart';
import '../identity/add_edit_identity_screen.dart';

class AddItemSheet extends StatelessWidget {
  const AddItemSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AddItemSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Add to Vault',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose an item type to encrypt on-device.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildGridOption(
                  context: context,
                  icon: Icons.lock_outline,
                  color: const Color(0xFF3B82F6),
                  title: 'Login',
                  subtitle: 'Password & accounts',
                  onTap: () => const AddEditEntryScreen(),
                ),
                _buildGridOption(
                  context: context,
                  icon: Icons.description_outlined,
                  color: const Color(0xFFF59E0B),
                  title: 'Secure Note',
                  subtitle: 'Encrypted private memo',
                  onTap: () => const AddEditSecureNoteScreen(),
                ),
                _buildGridOption(
                  context: context,
                  icon: Icons.credit_card,
                  color: const Color(0xFFA855F7),
                  title: 'Credit Card',
                  subtitle: 'Cards, CVV & PINs',
                  onTap: () => const AddCreditCardScreen(),
                ),
                _buildGridOption(
                  context: context,
                  icon: Icons.access_time,
                  color: const Color(0xFF10B981),
                  title: '2FA Token',
                  subtitle: 'Time-based OTP',
                  onTap: () => const AddAuthenticatorScreen(),
                ),
                _buildGridOption(
                  context: context,
                  icon: Icons.wifi,
                  color: const Color(0xFF06B6D4),
                  title: 'Wi-Fi Network',
                  subtitle: 'SSID & network pass',
                  onTap: () => const AddEditWifiScreen(),
                ),
                _buildGridOption(
                  context: context,
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF6366F1),
                  title: 'Identity',
                  subtitle: 'Profile, IDs & passport',
                  onTap: () => const AddEditIdentityScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOption({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => onTap()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
