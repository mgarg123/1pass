import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/storage_mode.dart';
import '../../../core/sync/generic_rest_sync_backend.dart';

const _byodDocsUrl = 'https://github.com/mgarg123/1Pass/tree/main/README.md';

class ByodSetupScreen extends ConsumerStatefulWidget {
  const ByodSetupScreen({super.key});

  @override
  ConsumerState<ByodSetupScreen> createState() => _ByodSetupScreenState();
}

class _ByodSetupScreenState extends ConsumerState<ByodSetupScreen> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isTesting = false;
  bool _testPassed = false;
  String? _testError;
  bool _supportsAtomicRotation = false;
  bool _showGuide = true;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(() {
        _testError = 'Please fill in both fields.';
        _testPassed = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testError = null;
      _testPassed = false;
    });

    final backend = GenericRestSyncBackend(baseUrl: url, apiKey: apiKey);
    final error = await backend.testConnection();

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      if (error == null) {
        _testPassed = true;
        _supportsAtomicRotation = backend.supportsAtomicRotation;
        _testError = null;
      } else {
        _testPassed = false;
        _testError = error;
      }
    });
  }

  Future<void> _confirm() async {
    final config = StorageModeConfig(
      mode: StorageMode.byodSync,
      byodUrl: _urlController.text.trim(),
      byodApiKey: _apiKeyController.text.trim(),
    );
    await ref.read(storageModeProvider.notifier).setMode(config);

    if (mounted) {
      // Pop back to auth gate which will now see BYOD mode
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openDocs() async {
    final uri = Uri.parse(_byodDocsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for when canLaunchUrl fails (e.g. missing intent queries)
        final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the link.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    const green = Color(0xFF10B981);
    const cardBg = Color(0xFF141414);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Connect Your Server'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── What is BYOD? ──
              _buildGuideSection(amber, green, cardBg),
              const SizedBox(height: 28),

              // ── Connection Form ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cable, color: amber, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Server Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // API Endpoint URL
                    const Text(
                      'API Endpoint',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://your-server.example.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (_) => setState(() {
                        _testPassed = false;
                        _testError = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // API Key
                    const Text(
                      'API Key',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Your secret API key',
                        prefixIcon: Icon(Icons.key),
                      ),
                      onChanged: (_) => setState(() {
                        _testPassed = false;
                        _testError = null;
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Test Connection Button
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                            )
                          : Icon(
                              _testPassed ? Icons.check_circle : Icons.wifi_tethering,
                              color: _testPassed ? green : null,
                            ),
                      label: Text(
                        _isTesting
                            ? 'Testing...'
                            : _testPassed
                                ? 'Connection Successful'
                                : 'Test Connection',
                        style: TextStyle(
                          color: _testPassed ? green : null,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _testPassed
                              ? green
                              : _testError != null
                                  ? Colors.redAccent
                                  : const Color(0xFF444444),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    // Test result
                    if (_testError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_testPassed) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Server is reachable and authenticated.',
                                    style: TextStyle(color: green, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _supportsAtomicRotation ? Icons.check_circle : Icons.info_outline,
                                  color: _supportsAtomicRotation ? green : Colors.white38,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _supportsAtomicRotation
                                        ? 'Atomic password rotation: supported'
                                        : 'Atomic password rotation: not supported (client fallback will be used)',
                                    style: TextStyle(
                                      color: _supportsAtomicRotation ? green : Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 24),

              // Confirm Button
              ElevatedButton(
                onPressed: _testPassed ? _confirm : null,
                child: const Text('Connect & Continue'),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('← Back to mode selection'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection(Color amber, Color green, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsible guide header
        GestureDetector(
          onTap: () => setState(() => _showGuide = !_showGuide),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(_showGuide ? 0 : 16),
              ),
              border: Border.all(color: amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined, color: amber, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What is Bring Your Own DB?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap to learn how to set up your server',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showGuide ? Icons.expand_less : Icons.expand_more,
                  color: amber,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),

        // Guide body
        if (_showGuide)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BYOD lets you sync your encrypted vault to a server you control — '
                    'instead of our cloud. Your passwords remain encrypted end-to-end; '
                    'the server only stores unreadable blobs.',
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Step-by-step
                  _buildStep(
                    number: '1',
                    title: 'Deploy a server',
                    description: 'Use one of our ready-made templates:',
                    color: amber,
                  ),
                  const SizedBox(height: 8),
                  _buildOptionChip(
                    icon: Icons.cloud_outlined,
                    label: 'Cloudflare Worker',
                    detail: 'Free, deploy in 5 min',
                    color: const Color(0xFFF48120),
                  ),
                  const SizedBox(height: 6),
                  _buildOptionChip(
                    icon: Icons.dns_outlined,
                    label: 'Docker + Postgres',
                    detail: 'Self-hosted on VPS or NAS',
                    color: const Color(0xFF0db7ed),
                  ),
                  const SizedBox(height: 16),

                  _buildStep(
                    number: '2',
                    title: 'Set your API key',
                    description: 'Your server creates a secret key during setup. '
                        'Copy it — you\'ll paste it below.',
                    color: amber,
                  ),
                  const SizedBox(height: 16),

                  _buildStep(
                    number: '3',
                    title: 'Enter the URL & key below',
                    description: 'Paste your server URL and API key, then tap "Test Connection" '
                        'to verify everything works.',
                    color: amber,
                  ),
                  const SizedBox(height: 20),

                  // Open docs button
                  OutlinedButton.icon(
                    onPressed: _openDocs,
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('View Setup Guide & Templates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: amber,
                      side: BorderSide(color: amber.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The full guide, SQL schemas, and deployment scripts are on our GitHub.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 38),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
