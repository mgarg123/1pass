import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'entry_type.dart';

class PasswordHistoryItem extends Equatable {
  final String password;
  final DateTime changedAt;

  const PasswordHistoryItem({required this.password, required this.changedAt});

  Map<String, dynamic> toJson() => {
        'password': password,
        'changedAt': changedAt.toIso8601String(),
      };

  factory PasswordHistoryItem.fromJson(Map<String, dynamic> json) {
    return PasswordHistoryItem(
      password: json['password'] as String,
      changedAt: DateTime.parse(json['changedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [password, changedAt];
}

class CustomField extends Equatable {
  final String name;
  final String value;
  final bool isObscured;

  const CustomField({
    required this.name,
    required this.value,
    this.isObscured = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'isObscured': isObscured,
      };

  factory CustomField.fromJson(Map<String, dynamic> json) {
    return CustomField(
      name: json['name'] as String,
      value: json['value'] as String,
      isObscured: json['isObscured'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [name, value, isObscured];
}

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
  final String? passkeyRelyingPartyId;
  final String? passkeyUserHandle;
  final String? passkeyPublicKey;
  final String? passkeyPrivateKey;
  final List<String> tags;
  final List<String> ignoredWarnings;
  final List<PasswordHistoryItem> passwordHistory;
  final List<CustomField> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isFavorite;

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
    this.passkeyRelyingPartyId,
    this.passkeyUserHandle,
    this.passkeyPublicKey,
    this.passkeyPrivateKey,
    required this.tags,
    this.ignoredWarnings = const [],
    this.passwordHistory = const [],
    this.customFields = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isFavorite = false,
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
    String? passkeyRelyingPartyId,
    String? passkeyUserHandle,
    String? passkeyPublicKey,
    String? passkeyPrivateKey,
    List<String>? tags,
    List<String>? ignoredWarnings,
    List<PasswordHistoryItem>? passwordHistory,
    List<CustomField>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isFavorite,
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
      passkeyRelyingPartyId: passkeyRelyingPartyId ?? this.passkeyRelyingPartyId,
      passkeyUserHandle: passkeyUserHandle ?? this.passkeyUserHandle,
      passkeyPublicKey: passkeyPublicKey ?? this.passkeyPublicKey,
      passkeyPrivateKey: passkeyPrivateKey ?? this.passkeyPrivateKey,
      tags: tags ?? this.tags,
      ignoredWarnings: ignoredWarnings ?? this.ignoredWarnings,
      passwordHistory: passwordHistory ?? this.passwordHistory,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
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
      'passkeyRelyingPartyId': passkeyRelyingPartyId,
      'passkeyUserHandle': passkeyUserHandle,
      'passkeyPublicKey': passkeyPublicKey,
      'passkeyPrivateKey': passkeyPrivateKey,
      'tags': tags,
      'ignoredWarnings': ignoredWarnings,
      'passwordHistory': passwordHistory.map((e) => e.toJson()).toList(),
      'customFields': customFields.map((e) => e.toJson()).toList(),
      'isFavorite': isFavorite,
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
        passkeyRelyingPartyId,
        passkeyUserHandle,
        passkeyPublicKey,
        passkeyPrivateKey,
        tags,
        ignoredWarnings,
        passwordHistory,
        customFields,
        createdAt,
        updatedAt,
        isDeleted,
        isFavorite,
      ];
}
