import 'dart:typed_data';
void main() {
  var b = ByteData(8);
  b.setInt64(0, 42, Endian.little);
  print('42 int: ' + b.buffer.asUint8List().map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  b.setFloat64(0, 42.0, Endian.little);
  print('42 double: ' + b.buffer.asUint8List().map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
  b.setFloat64(0, 3.14, Endian.little);
  print('3.14 double: ' + b.buffer.asUint8List().map((e)=>e.toRadixString(16).padLeft(2,'0')).join(' '));
}
