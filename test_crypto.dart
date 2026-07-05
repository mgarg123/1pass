import 'package:cryptography/cryptography.dart';
void main() {
  final random = SecureRandom.fast;
  print(random.nextBytes(12));
}
