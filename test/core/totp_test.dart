import 'package:flutter_test/flutter_test.dart';
import 'package:otp/otp.dart';

void main() {
  group('TOTP Correctness Tests', () {
    test('RFC 6238 Test Vector 1', () {
      // Secret is '12345678901234567890' (ASCII)
      // Base32 encoded: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
      const secretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      
      // Test time: 59 seconds after epoch (1970-01-01 00:00:59 UTC)
      const timeMs = 59 * 1000;
      
      // Expected TOTP (6 digits, interval 30s)
      const expectedCode = '287082';

      final code = OTP.generateTOTPCodeString(
        secretBase32,
        timeMs,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      expect(code, expectedCode, reason: 'TOTP generated code does not match RFC 6238 expected test vector.');
    });
  });
}
