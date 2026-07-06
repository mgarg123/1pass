import 'dart:math' as math;
import 'wordlist.dart';

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
    
    final result = StringBuffer();
    for (int i = 0; i < length; i++) {
      // Use unbiased selection for characters as well for consistency
      final randomIndex = _getUnbiasedRandomInt(charSet.length);
      result.write(charSet[randomIndex]);
    }
    
    return result.toString();
  }

  static String generatePassphrase({
    int wordCount = 5,
    String separator = '-',
    bool capitalize = false,
    bool includeNumber = false,
  }) {
    if (wordCount < 1) return '';
    if (effLargeWordlist.isEmpty) return '';
    
    final words = <String>[];
    for (int i = 0; i < wordCount; i++) {
      int index = _getUnbiasedRandomInt(effLargeWordlist.length);
      String word = effLargeWordlist[index];
      if (capitalize && word.isNotEmpty) {
        word = word[0].toUpperCase() + word.substring(1);
      }
      words.add(word);
    }
    
    if (includeNumber) {
      // randomly append a number from 0-9 to one of the words
      int wordToModify = _getUnbiasedRandomInt(wordCount);
      int numberToAppend = _getUnbiasedRandomInt(10);
      words[wordToModify] = '${words[wordToModify]}$numberToAppend';
    }
    
    return words.join(separator);
  }

  /// Secure unbiased random selection using rejection sampling.
  /// Generates 2 random bytes (0-65535) and rejects values outside a clean multiple of [max].
  static int _getUnbiasedRandomInt(int max) {
    if (max <= 0) return 0;
    if (max > 65535) throw ArgumentError('max > 65535 not supported');
    
    final random = math.Random.secure();
    final limit = 65536 - (65536 % max);
    
    while (true) {
      // Pull 2 random bytes
      final byte0 = random.nextInt(256);
      final byte1 = random.nextInt(256);
      final val = byte0 | (byte1 << 8);
      
      // Reject and retry if value falls outside clean multiple of max to avoid modulo bias
      if (val < limit) {
        return val % max;
      }
    }
  }
}
