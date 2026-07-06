import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

class BreachCheckerService {
  final Dio _dio = Dio();
  final Sha1 _sha1 = Sha1();

  Future<int> checkPasswordBreachCount(String password) async {
    if (password.isEmpty) return 0;
    
    try {
      // Hash password using Sha1 from cryptography package
      final hash = await _sha1.hash(utf8.encode(password));
      final hashBytes = hash.bytes;
      final sha1Hash = hashBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      
      final prefix = sha1Hash.substring(0, 5);
      final suffix = sha1Hash.substring(5);

      final response = await _dio.get(
        'https://api.pwnedpasswords.com/range/$prefix',
        options: Options(
          headers: {'User-Agent': 'OnePass-Password-Manager'},
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('HIBP check failed: ${response.statusCode}');
      }

      final lines = response.data.toString().split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(':');
        if (parts.length >= 2 && parts[0].toUpperCase() == suffix) {
          return int.tryParse(parts[1].trim()) ?? 0;
        }
      }
      return 0;
    } catch (e) {
      // Return -1 to indicate an error (e.g., no internet connection)
      // so the UI can decide whether to show an error or just ignore it.
      return -1;
    }
  }
}
