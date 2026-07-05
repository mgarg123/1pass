import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../constants/crypto_constants.dart';
import 'crypto_models.dart';

class DecryptionFailedException implements Exception {
  final String message;
  DecryptionFailedException([this.message = 'Decryption failed: tampered data or wrong key.']);
  
  @override
  String toString() => 'DecryptionFailedException: $message';
}

class CryptoService {
  /// Generates a cryptographically secure random Salt
  Future<Salt> generateSalt() async {
    final bytes = _generateRandomBytes(CryptoConstants.saltLengthBytes);
    return Salt(bytes);
  }

  Uint8List _generateRandomBytes(int length) {
    final random = SecureRandom.fast;
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Derives an EncryptionKey from a master password and salt using Argon2id
  Future<EncryptionKey> deriveKey({
    required String password,
    required Salt salt,
  }) async {
    final argon2 = Argon2id(
      memory: CryptoConstants.argon2MemoryKB,
      iterations: CryptoConstants.argon2Iterations,
      parallelism: CryptoConstants.argon2Parallelism,
      hashLength: CryptoConstants.keyLengthBytes,
    );

    final secretKey = await argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt.bytes,
    );

    final bytes = await secretKey.extractBytes();
    
    // In cryptography package, the SecretKey instance holds the bytes in memory.
    // If the package exposes a way to destroy it, we would call it. 
    // Dart doesn't have explicit manual memory management, so we do our best 
    // with our EncryptionKey wrapper which allows clearing its own copy.

    return EncryptionKey(Uint8List.fromList(bytes));
  }

  /// Encrypts plaintext using AES-256-GCM.
  /// Generates a fresh random nonce on every call.
  Future<EncryptedBlob> encrypt(Uint8List plaintext, EncryptionKey key) async {
    final algorithm = AesGcm.with256bits();
    
    // Generate fresh 12-byte nonce
    final nonceList = _generateRandomBytes(CryptoConstants.nonceLengthBytes);
    final nonce = Nonce(nonceList);

    final secretKey = SecretKey(key.bytes);

    try {
      final secretBox = await algorithm.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce.bytes,
      );

      return EncryptedBlob(
        cipherText: Uint8List.fromList(secretBox.cipherText),
        nonce: nonce,
        mac: Uint8List.fromList(secretBox.mac.bytes),
      );
    } finally {
      // Best effort to not let SecretKey leak if the package caches it.
      // We rely on the caller to clear the EncryptionKey when done.
    }
  }

  /// Decrypts an EncryptedBlob using AES-256-GCM.
  /// Throws DecryptionFailedException on failure (tamper detection or wrong key).
  Future<Uint8List> decrypt(EncryptedBlob blob, EncryptionKey key) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key.bytes);

    final secretBox = SecretBox(
      blob.cipherText,
      nonce: blob.nonce.bytes,
      mac: Mac(blob.mac),
    );

    try {
      final clearText = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw DecryptionFailedException('Authentication failed: wrong key or data was tampered.');
    } catch (e) {
      throw DecryptionFailedException('Decryption failed: $e');
    }
  }
}
