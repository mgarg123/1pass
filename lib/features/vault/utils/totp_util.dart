import 'package:otp/otp.dart';

typedef TotpParseResult = ({String secret, String? issuer, String? accountName});

class TotpUtil {
  /// Parses a raw base32 secret or an otpauth:// URI.
  static TotpParseResult parse(String input) {
    var secret = input.trim();
    String? issuer;
    String? accountName;
    
    if (secret.startsWith('otpauth://')) {
      try {
        final uri = Uri.parse(secret);
        if (uri.queryParameters.containsKey('secret')) {
          secret = uri.queryParameters['secret']!;
        }
        issuer = uri.queryParameters['issuer'];
        
        if (uri.pathSegments.isNotEmpty) {
          final path = uri.pathSegments.last;
          final parts = path.split(':');
          if (parts.length > 1) {
            issuer ??= Uri.decodeComponent(parts[0]);
            accountName = Uri.decodeComponent(parts[1]);
          } else {
            accountName = Uri.decodeComponent(parts[0]);
          }
        }
      } catch (_) {
        // Fallback to raw string if URI parsing fails
      }
    }
    
    return (
      secret: secret.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      issuer: issuer,
      accountName: accountName,
    );
  }

  /// Validates if a string is a valid base32 secret.
  static bool isValidBase32(String secret) {
    if (secret.isEmpty) return false;
    final base32Regex = RegExp(r'^[A-Z2-7=]+$');
    return base32Regex.hasMatch(secret);
  }

  /// Generates the current 6-digit TOTP code for the given secret.
  static String generateCode(String secret) {
    if (!isValidBase32(secret)) return '------';
    
    try {
      final code = OTP.generateTOTPCodeString(
        secret,
        DateTime.now().millisecondsSinceEpoch,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true, // Uses standard RFC 6238 which Google Authenticator uses
      );
      // Format as XXX XXX
      return '${code.substring(0, 3)} ${code.substring(3)}';
    } catch (e) {
      return 'ERROR';
    }
  }

  /// Calculates the remaining seconds in the current 30-second window.
  static int getRemainingSeconds() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 30 - ((now ~/ 1000) % 30);
  }
}
