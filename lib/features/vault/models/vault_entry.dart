import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'entry_type.dart';

class VaultEntry extends Equatable {
  final String id;
  final EntryType type;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final String? totpSecret;
  final String? cardNumber;
  final String? cardholderName;
  final String? expiryDate;
  final String? cvv;
  final String? pin;
  final String? bankName;
  final List<String> tags;
  final List<String> ignoredWarnings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const VaultEntry({
    required this.id,
    this.type = EntryType.login,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    this.totpSecret,
    this.cardNumber,
    this.cardholderName,
    this.expiryDate,
    this.cvv,
    this.pin,
    this.bankName,
    required this.tags,
    this.ignoredWarnings = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  VaultEntry copyWith({
    String? id,
    EntryType? type,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? totpSecret,
    String? cardNumber,
    String? cardholderName,
    String? expiryDate,
    String? cvv,
    String? pin,
    String? bankName,
    List<String>? tags,
    List<String>? ignoredWarnings,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      totpSecret: totpSecret ?? this.totpSecret,
      cardNumber: cardNumber ?? this.cardNumber,
      cardholderName: cardholderName ?? this.cardholderName,
      expiryDate: expiryDate ?? this.expiryDate,
      cvv: cvv ?? this.cvv,
      pin: pin ?? this.pin,
      bankName: bankName ?? this.bankName,
      tags: tags ?? this.tags,
      ignoredWarnings: ignoredWarnings ?? this.ignoredWarnings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Serializes sensitive fields to a JSON string for encryption.
  String get sensitivePayload {
    return jsonEncode({
      'type': type.name,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'totpSecret': totpSecret,
      'cardNumber': cardNumber,
      'cardholderName': cardholderName,
      'expiryDate': expiryDate,
      'cvv': cvv,
      'pin': pin,
      'bankName': bankName,
      'tags': tags,
      'ignoredWarnings': ignoredWarnings,
    });
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        username,
        password,
        url,
        notes,
        totpSecret,
        cardNumber,
        cardholderName,
        expiryDate,
        cvv,
        pin,
        bankName,
        tags,
        ignoredWarnings,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
