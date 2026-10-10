import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';
import '../../../../core/utils/clipboard_util.dart';
import 'add_edit_wifi_screen.dart';

class ViewWifiScreen extends ConsumerStatefulWidget {
  final VaultEntry entry;

  const ViewWifiScreen({super.key, required this.entry});

  @override
  ConsumerState<ViewWifiScreen> createState() => _ViewWifiScreenState();
}

class _ViewWifiScreenState extends ConsumerState<ViewWifiScreen> {
  bool _obscurePassword = true;

  void _copyToClipboard(String text, String label) {
    ClipboardUtil.copyTemporary(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  String _buildWifiQrString(String ssid, String password, String securityType, bool isHidden) {
    String typeCode = 'WPA';
    if (securityType.contains('WEP')) {
      typeCode = 'WEP';
    } else if (securityType.contains('Open') || securityType.contains('None')) {
      typeCode = 'nopass';
    }
    
    final hiddenStr = isHidden ? 'H:true;' : '';
    return 'WIFI:S:$ssid;T:$typeCode;P:$password;$hiddenStr;';
  }

  void _showQrBottomSheet(BuildContext context, String ssid, String password, String securityType, bool isHidden) {
    final qrData = _buildWifiQrString(ssid, password, securityType, isHidden);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar: Drag handle + Close X button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36), // Balance the close button
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2E),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title & Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi, size: 22, color: Colors.cyan),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ssid,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan with camera to connect instantly',
                style: TextStyle(fontSize: 13, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 210.0,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Security Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      securityType,
                      style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isHidden) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'Hidden SSID',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),

              if (password.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _copyToClipboard(password, 'Wi-Fi Password');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(vaultProvider);
    final currentEntry = asyncEntries.value?.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == widget.entry.id,
      orElse: () => null,
    ) ?? widget.entry;

    final ssid = currentEntry.wifiSsid ?? currentEntry.title;
    final password = currentEntry.wifiPassword ?? currentEntry.password;
    final securityType = currentEntry.wifiSecurityType ?? 'WPA/WPA2';
    final isHidden = currentEntry.wifiIsHidden ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Network'),
        actions: [
          IconButton(
            icon: Icon(
              currentEntry.isFavorite ? Icons.star : Icons.star_border,
              color: currentEntry.isFavorite ? Colors.amber : Colors.white70,
            ),
            tooltip: currentEntry.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () {
              ref.read(vaultProvider.notifier).toggleFavorite(currentEntry);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Wi-Fi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditWifiScreen(entry: currentEntry),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Wi-Fi Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.wifi, color: Colors.cyan, size: 36),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ssid,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (currentEntry.title.isNotEmpty && currentEntry.title != ssid) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentEntry.title,
                        style: const TextStyle(fontSize: 14, color: Colors.white54),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            securityType,
                            style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isHidden) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Hidden',
                              style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Action: Show QR Code
                    ElevatedButton.icon(
                      onPressed: () => _showQrBottomSheet(context, ssid, password, securityType, isHidden),
                      icon: const Icon(Icons.qr_code, size: 20),
                      label: const Text('Show Guest QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Credentials Card
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.wifi, color: Colors.cyan),
                    title: const Text('Network Name (SSID)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    subtitle: Text(ssid, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white38),
                      tooltip: 'Copy SSID',
                      onPressed: () => _copyToClipboard(ssid, 'Network SSID'),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.cyan),
                    title: const Text('Password', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    subtitle: Text(
                      _obscurePassword ? '••••••••••••' : (password.isNotEmpty ? password : '(None)'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: _obscurePassword ? 2 : 0,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white38),
                          tooltip: 'Copy Password',
                          onPressed: password.isEmpty ? null : () => _copyToClipboard(password, 'Password'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (currentEntry.notes != null && currentEntry.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOTES / ROUTER INFO',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        currentEntry.notes!,
                        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (currentEntry.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: currentEntry.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${DateFormat.yMMMd().format(currentEntry.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    'Updated: ${DateFormat.yMMMd().format(currentEntry.updatedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ].animate(interval: 50.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}
