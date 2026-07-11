import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/storage_mode.dart';
import 'byod_setup_screen.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/1pass.png',
                  height: 80,
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOut),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose Your Setup',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              const Text(
                'How would you like to store your vault?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 40),

              // ── Local Only ──
              _ModeCard(
                icon: Icons.smartphone,
                iconColor: const Color(0xFF10B981),
                title: 'Local Only',
                subtitle: 'Your data stays on this device. No account needed. Maximum privacy.',
                badge: 'MOST PRIVATE',
                badgeColor: const Color(0xFF10B981),
                onTap: () => _selectMode(context, ref, StorageMode.localOnly),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
              const SizedBox(height: 16),

              // ── Cloud Sync ──
              _ModeCard(
                icon: Icons.cloud_sync,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Cloud Sync',
                subtitle: 'Sync across all your devices securely via our cloud (powered by Supabase).',
                badge: 'RECOMMENDED',
                badgeColor: const Color(0xFF8B5CF6),
                onTap: () => _selectMode(context, ref, StorageMode.cloudSync),
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
              const SizedBox(height: 16),

              // ── BYOD ──
              _ModeCard(
                icon: Icons.dns_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Bring Your Own DB',
                subtitle: 'Sync via your own server. Requires basic setup — we provide ready-made templates.',
                badge: 'ADVANCED',
                badgeColor: const Color(0xFFF59E0B),
                onTap: () => _selectByod(context, ref),
              ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'All modes use the same zero-knowledge encryption. '
                  'Your passwords are always encrypted on-device — '
                  'even we can never see them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectMode(BuildContext context, WidgetRef ref, StorageMode mode) async {
    final config = StorageModeConfig(mode: mode);
    await ref.read(storageModeProvider.notifier).setMode(config);

    // Initialize Supabase if cloud mode was selected and not already initialized
    if (mode == StorageMode.cloudSync) {
      try {
        // Check if Supabase is already initialized
        Supabase.instance.client;
      } catch (_) {
        // Not initialized yet — do it now
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
          await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing Supabase credentials in .env file.')),
            );
          }
          return;
        }
      }
    }
  }

  void _selectByod(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ByodSetupScreen()),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
