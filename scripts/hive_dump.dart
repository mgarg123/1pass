import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';

void main() async {
  final path = Directory.current.path + '/test_hive';
  Hive.init(path);
  
  final box = await Hive.openBox('test_box');
  await box.put('1', {
    't': true,
    'f': false,
    'i': 42,
    'd': 3.14,
    's': 'a'
  });
  
  await box.close();
  
  final file = File(path + '/test_box.hive');
  final bytes = await file.readAsBytes();
  
  print('Total bytes: ${bytes.length}');
  print('Hex dump:');
  for (int i = 0; i < bytes.length; i += 16) {
    final end = (i + 16 < bytes.length) ? i + 16 : bytes.length;
    final chunk = bytes.sublist(i, end);
    final hexStr = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('${i.toString().padLeft(4, '0')}: $hexStr');
  }
}
