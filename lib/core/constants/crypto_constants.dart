class CryptoConstants {
  static const int argon2MemoryKB = 65536; // 64 MB
  static const int argon2Iterations = 3;
  static const int argon2Parallelism = 4;
  
  static const int keyLengthBytes = 32;  // AES-256
  static const int nonceLengthBytes = 12; // AES-GCM standard
  static const int saltLengthBytes = 16;
}
