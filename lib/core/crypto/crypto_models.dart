import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../constants/crypto_constants.dart';

/// Wraps a 32-byte encryption key
class EncryptionKey extends Equatable {
  final Uint8List bytes;

  EncryptionKey(this.bytes) {
    if (bytes.length != CryptoConstants.keyLengthBytes) {
      throw ArgumentError('EncryptionKey must be exactly ${CryptoConstants.keyLengthBytes} bytes long.');
    }
  }

  /// Clears the key material from memory by overwriting with zeros.
  /// Note: Dart's garbage collector may have already copied this memory,
  /// so this is a best-effort defense-in-depth measure.
  void clear() {
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  @override
  List<Object?> get props => [bytes];
}

/// Wraps a 12-byte nonce
class Nonce extends Equatable {
  final Uint8List bytes;

  Nonce(this.bytes) {
    if (bytes.length != CryptoConstants.nonceLengthBytes) {
      throw ArgumentError('Nonce must be exactly ${CryptoConstants.nonceLengthBytes} bytes long.');
    }
  }

  String toBase64() => base64Encode(bytes);

  factory Nonce.fromBase64(String base64) => Nonce(base64Decode(base64));

  @override
  List<Object?> get props => [bytes];
}

/// Wraps a 16-byte salt
class Salt extends Equatable {
  final Uint8List bytes;

  Salt(this.bytes) {
    if (bytes.length != CryptoConstants.saltLengthBytes) {
      throw ArgumentError('Salt must be exactly ${CryptoConstants.saltLengthBytes} bytes long.');
    }
  }

  String toBase64() => base64Encode(bytes);

  factory Salt.fromBase64(String base64) => Salt(base64Decode(base64));

  @override
  List<Object?> get props => [bytes];
}

/// Holds ciphertext, nonce, and auth tag.
/// In AES-GCM (using the cryptography package), the mac (auth tag) is usually 
/// appended to or handled alongside the ciphertext. For this model, we'll store
/// the raw combined ciphertext (which includes the MAC as per cryptography's SecretBox)
/// and the nonce.
class EncryptedBlob extends Equatable {
  final Uint8List cipherText; // typically includes the MAC in SecretBox
  final Nonce nonce;
  final Uint8List mac; // The auth tag

  const EncryptedBlob({
    required this.cipherText,
    required this.nonce,
    required this.mac,
  });

  /// Encodes the blob for storage. Format: base64(nonce):base64(cipherText):base64(mac)
  String toStorageString() {
    final nonceStr = nonce.toBase64();
    final cipherStr = base64Encode(cipherText);
    final macStr = base64Encode(mac);
    return '$nonceStr:$cipherStr:$macStr';
  }

  /// Decodes from storage string
  factory EncryptedBlob.fromStorageString(String storageString) {
    final parts = storageString.split(':');
    if (parts.length != 3) {
      throw const FormatException('Invalid EncryptedBlob storage format.');
    }
    return EncryptedBlob(
      nonce: Nonce.fromBase64(parts[0]),
      cipherText: base64Decode(parts[1]),
      mac: base64Decode(parts[2]),
    );
  }

  @override
  List<Object?> get props => [cipherText, nonce, mac];
}

/// Represents the parameters used for Argon2id key derivation.
class Argon2Params extends Equatable {
  final int memoryKB;
  final int iterations;
  final int parallelism;
  final int hashLengthBytes;

  const Argon2Params({
    required this.memoryKB,
    required this.iterations,
    required this.parallelism,
    required this.hashLengthBytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'memory_kb': memoryKB,
      'iterations': iterations,
      'parallelism': parallelism,
      'hash_length_bytes': hashLengthBytes,
    };
  }

  factory Argon2Params.fromJson(Map<String, dynamic> json) {
    return Argon2Params(
      memoryKB: json['memory_kb'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
      hashLengthBytes: json['hash_length_bytes'] as int,
    );
  }

  @override
  List<Object?> get props => [memoryKB, iterations, parallelism, hashLengthBytes];
}
