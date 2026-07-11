import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Logo Animation
              Center(
                child: Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/images/1pass.png',
                    height: 100,
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: -8, end: 8, duration: 2.seconds, curve: Curves.easeInOut),
                ),
              ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 48),

              // Welcome Text
              Text(
                'Welcome to 1Pass',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 16),
              
              const Text(
                'The flexible, privacy-first password manager that puts you in full control of your data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 16, height: 1.5),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 48),

              // Feature Highlights
              _buildFeatureRow(
                icon: Icons.shield_outlined,
                title: 'Zero-Knowledge Encryption',
                description: 'Your data is encrypted on-device. Only you hold the keys.',
                delay: 700,
              ),
              const SizedBox(height: 24),
              _buildFeatureRow(
                icon: Icons.public_off_outlined,
                title: 'True Ownership',
                description: 'Store locally, sync with our cloud, or bring your own server.',
                delay: 900,
              ),
              const SizedBox(height: 24),
              _buildFeatureRow(
                icon: Icons.fingerprint,
                title: 'Biometric Security',
                description: 'Seamless and secure access using your device biometrics.',
                delay: 1100,
              ),

              const Spacer(flex: 3),

              // Get Started Button
              ElevatedButton(
                onPressed: onGetStarted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: primaryColor.withValues(alpha: 0.5),
                ),
                child: Text(
                  'Get Started',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ).animate().fadeIn(delay: 1400.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ].animate().fadeIn(delay: delay.ms).slideX(begin: -0.1, end: 0),
    );
  }
}
