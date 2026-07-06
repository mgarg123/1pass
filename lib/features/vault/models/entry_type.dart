enum EntryType {
  login,
  authenticator,
  creditCard;

  String get displayName {
    switch (this) {
      case EntryType.login:
        return 'Login / Password';
      case EntryType.authenticator:
        return 'Authenticator (2FA)';
      case EntryType.creditCard:
        return 'Credit Card';
    }
  }
}
