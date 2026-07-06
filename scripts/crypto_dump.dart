import 'dart:convert';
import 'dart:typed_data';
import 'package:one_pass/core/crypto/crypto_models.dart';
import 'package:one_pass/core/crypto/crypto_service.dart';

void main() async {
  final crypto = CryptoService();
  final keyBytes = Uint8List(32);
  for(int i=0; i<32; i++) keyBytes[i] = i;
  final key = EncryptionKey(keyBytes);
  
  final plaintext = utf8.encode('Hello, Kotlin from Dart!');
  final blob = await crypto.encrypt(Uint8List.fromList(plaintext), key);
  
  print('Key: ' + key.bytes.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  print('Nonce: ' + blob.nonce.bytes.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  print('Ciphertext: ' + blob.cipherText.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  print('MAC: ' + blob.mac.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  print('Storage format: ' + blob.toStorageString());
}
