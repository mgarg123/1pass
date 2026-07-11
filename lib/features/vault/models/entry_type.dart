import 'package:flutter/material.dart';

enum EntryType {
  login,
  authenticator,
  creditCard,
  secureNote,
  wifi,
  identity,
  passkey;

  String get displayName {
    switch (this) {
      case EntryType.login:
        return 'Login / Password';
      case EntryType.authenticator:
        return 'Authenticator (2FA)';
      case EntryType.creditCard:
        return 'Credit Card';
      case EntryType.secureNote:
        return 'Secure Note';
      case EntryType.wifi:
        return 'Wi-Fi Password';
      case EntryType.identity:
        return 'Identity';
      case EntryType.passkey:
        return 'Passkey';
    }
  }

  Color get color {
    switch (this) {
      case EntryType.login:
        return Colors.blue;
      case EntryType.creditCard:
        return Colors.purple;
      case EntryType.authenticator:
        return Colors.green;
      case EntryType.secureNote:
        return Colors.orange;
      case EntryType.wifi:
        return Colors.cyan;
      case EntryType.identity:
        return Colors.indigo;
      case EntryType.passkey:
        return Colors.deepPurple;
    }
  }
}
