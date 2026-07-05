import 'package:cryptography/cryptography.dart';

class GeneratorService {
  static String generate({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    final chars = StringBuffer();
    if (uppercase) chars.write('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (lowercase) chars.write('abcdefghijklmnopqrstuvwxyz');
    if (numbers) chars.write('0123456789');
    if (symbols) chars.write('!@#\$&*~_+-=?');

    if (chars.isEmpty) return '';

    final charSet = chars.toString();
    final random = SecureRandom.fast;
    
    final result = StringBuffer();
    for (int i = 0; i < length; i++) {
      final randomIndex = random.nextInt(charSet.length);
      result.write(charSet[randomIndex]);
    }
    
    return result.toString();
  }
}
