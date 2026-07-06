import 'package:flutter/material.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';

class EntryAvatarWidget extends StatelessWidget {
  final VaultEntry entry;

  const EntryAvatarWidget({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final entryColor = entry.type.color;
    final fallbackWidget = _buildFallback(entryColor);

    if (entry.type == EntryType.login && entry.url != null && entry.url!.trim().isNotEmpty) {
      final host = _extractHost(entry.url!);
      if (host != null) {
        final faviconUrl = 'https://www.google.com/s2/favicons?domain=$host&sz=64';
        
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: entryColor.withValues(alpha: 0.3)),
          ),
          child: ClipOval(
            child: Image.network(
              faviconUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallbackWidget,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return fallbackWidget; // show fallback while loading
              },
            ),
          ),
        );
      }
    }

    return fallbackWidget;
  }

  Widget _buildFallback(Color entryColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: entryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: entryColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: entry.type == EntryType.authenticator
            ? Icon(Icons.access_time, color: entryColor)
            : entry.type == EntryType.creditCard
                ? Icon(Icons.credit_card, color: entryColor)
                : Text(
                    entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: entryColor, fontSize: 18),
                  ),
      ),
    );
  }

  String? _extractHost(String urlString) {
    try {
      var uriStr = urlString.trim();
      if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
        uriStr = 'https://$uriStr';
      }
      final uri = Uri.parse(uriStr);
      return uri.host.isNotEmpty ? uri.host : null;
    } catch (_) {
      return null;
    }
  }
}
