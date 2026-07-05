import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/core/crypto/crypto_models.dart';
import 'package:one_pass/core/crypto/crypto_service.dart';
import 'package:one_pass/core/constants/crypto_constants.dart';

void main() {
  group('CryptoService Tests', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    test('Length validation', () async {
      final salt = await cryptoService.generateSalt();
      expect(salt.bytes.length, CryptoConstants.saltLengthBytes, reason: 'Salt length should be 16 bytes');

      final key = await cryptoService.deriveKey(password: 'my-super-secret-password', salt: salt);
      expect(key.bytes.length, CryptoConstants.keyLengthBytes, reason: 'Derived key length should be 32 bytes');

      final plaintext = utf8.encode('test-data');
      final blob = await cryptoService.encrypt(Uint8List.fromList(plaintext), key);
      
      expect(blob.nonce.bytes.length, CryptoConstants.nonceLengthBytes, reason: 'Nonce length should be 12 bytes');
    });

    test('Salt uniqueness', () async {
      final salt1 = await cryptoService.generateSalt();
      final salt2 = await cryptoService.generateSalt();
      
      expect(salt1, isNot(equals(salt2)), reason: 'Two generated salts should not be identical');
    });

    test('Round trip: encrypt plaintext → decrypt → output equals original plaintext', () async {
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'password123', salt: salt);
      
      final originalText = 'Hello, World! This is sensitive data.';
      final plaintext = Uint8List.fromList(utf8.encode(originalText));
      
      final encryptedBlob = await cryptoService.encrypt(plaintext, key);
      final decryptedBytes = await cryptoService.decrypt(encryptedBlob, key);
      
      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, originalText);
    });

    test('Tamper detection: flip one byte in the ciphertext', () async {
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'password123', salt: salt);
      
      final plaintext = Uint8List.fromList(utf8.encode('data to tamper'));
      final encryptedBlob = await cryptoService.encrypt(plaintext, key);
      
      // Tamper ciphertext
      final tamperedCiphertext = Uint8List.fromList(encryptedBlob.cipherText);
      if (tamperedCiphertext.isNotEmpty) {
        tamperedCiphertext[0] ^= 0xFF; // Flip bits
      }
      
      final tamperedBlob = EncryptedBlob(
        cipherText: tamperedCiphertext,
        nonce: encryptedBlob.nonce,
        mac: encryptedBlob.mac,
      );
      
      expect(
        () => cryptoService.decrypt(tamperedBlob, key),
        throwsA(isA<DecryptionFailedException>()),
        reason: 'Tampered ciphertext should throw DecryptionFailedException',
      );
    });

    test('Tamper detection on auth tag: flip one byte in the auth tag', () async {
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'password123', salt: salt);
      
      final plaintext = Uint8List.fromList(utf8.encode('data to tamper tag'));
      final encryptedBlob = await cryptoService.encrypt(plaintext, key);
      
      // Tamper MAC
      final tamperedMac = Uint8List.fromList(encryptedBlob.mac);
      if (tamperedMac.isNotEmpty) {
        tamperedMac[0] ^= 0xFF;
      }
      
      final tamperedBlob = EncryptedBlob(
        cipherText: encryptedBlob.cipherText,
        nonce: encryptedBlob.nonce,
        mac: tamperedMac,
      );
      
      expect(
        () => cryptoService.decrypt(tamperedBlob, key),
        throwsA(isA<DecryptionFailedException>()),
        reason: 'Tampered MAC should throw DecryptionFailedException',
      );
    });

    test('Wrong key', () async {
      final salt = await cryptoService.generateSalt();
      final keyA = await cryptoService.deriveKey(password: 'passwordA', salt: salt);
      final keyB = await cryptoService.deriveKey(password: 'passwordB', salt: salt);
      
      final plaintext = Uint8List.fromList(utf8.encode('secret stuff'));
      final encryptedBlob = await cryptoService.encrypt(plaintext, keyA);
      
      expect(
        () => cryptoService.decrypt(encryptedBlob, keyB),
        throwsA(isA<DecryptionFailedException>()),
        reason: 'Decrypting with wrong key should throw DecryptionFailedException',
      );
    });

    test('Nonce uniqueness', () async {
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'password123', salt: salt);
      
      final plaintext = Uint8List.fromList(utf8.encode('same message'));
      
      final encryptedBlob1 = await cryptoService.encrypt(plaintext, key);
      final encryptedBlob2 = await cryptoService.encrypt(plaintext, key);
      
      expect(encryptedBlob1.nonce, isNot(equals(encryptedBlob2.nonce)), reason: 'Nonces must be unique');
      expect(encryptedBlob1.cipherText, isNot(equals(encryptedBlob2.cipherText)), reason: 'Ciphertexts must be different for same plaintext if nonces are different');
    });

    test('Empty input handling', () async {
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'password123', salt: salt);
      
      final plaintext = Uint8List.fromList([]);
      
      // Should not throw
      final encryptedBlob = await cryptoService.encrypt(plaintext, key);
      
      final decryptedBytes = await cryptoService.decrypt(encryptedBlob, key);
      expect(decryptedBytes.isEmpty, isTrue, reason: 'Decrypted empty string should be empty list');
    });
  });
}
