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

class CustomFieldDetail extends Equatable {
  final String label;
  final String value;
  final bool isObscured;

  const CustomFieldDetail({
    required this.label,
    required this.value,
    this.isObscured = false,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'isObscured': isObscured,
      };

  factory CustomFieldDetail.fromJson(Map<String, dynamic> json) {
    return CustomFieldDetail(
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      isObscured: json['isObscured'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [label, value, isObscured];
}

class CustomField extends Equatable {
  final String name;
  final String value;
  final bool isObscured;
  final List<CustomFieldDetail> details;

  const CustomField({
    required this.name,
    required this.value,
    this.isObscured = false,
    this.details = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'isObscured': isObscured,
        if (details.isNotEmpty) 'details': details.map((d) => d.toJson()).toList(),
      };

  factory CustomField.fromJson(Map<String, dynamic> json) {
    final detailsList = json['details'] != null
        ? (json['details'] as List)
            .map((e) => CustomFieldDetail.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <CustomFieldDetail>[];

    return CustomField(
      name: json['name'] as String,
      value: json['value'] as String,
      isObscured: json['isObscured'] as bool? ?? false,
      details: detailsList,
    );
  }

  @override
  List<Object?> get props => [name, value, isObscured, details];
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

  // Wi-Fi specific fields
  final String? wifiSsid;
  final String? wifiPassword;
  final String? wifiSecurityType;
  final bool? wifiIsHidden;

  // Identity specific fields
  final String? identityTitle;
  final String? identityFirstName;
  final String? identityMiddleName;
  final String? identityLastName;
  final String? identityGender;
  final String? identityBirthDate;
  final String? identityEmail;
  final String? identityPhone;
  final String? identityAddress1;
  final String? identityAddress2;
  final String? identityCity;
  final String? identityState;
  final String? identityPostalCode;
  final String? identityCountry;
  final String? identityPassportNumber;
  final String? identityNationalId;
  final String? identityLicenseNumber;
  final String? identityCompany;
  final String? identityOccupation;

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
    this.wifiSsid,
    this.wifiPassword,
    this.wifiSecurityType,
    this.wifiIsHidden,
    this.identityTitle,
    this.identityFirstName,
    this.identityMiddleName,
    this.identityLastName,
    this.identityGender,
    this.identityBirthDate,
    this.identityEmail,
    this.identityPhone,
    this.identityAddress1,
    this.identityAddress2,
    this.identityCity,
    this.identityState,
    this.identityPostalCode,
    this.identityCountry,
    this.identityPassportNumber,
    this.identityNationalId,
    this.identityLicenseNumber,
    this.identityCompany,
    this.identityOccupation,
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
    String? wifiSsid,
    String? wifiPassword,
    String? wifiSecurityType,
    bool? wifiIsHidden,
    String? identityTitle,
    String? identityFirstName,
    String? identityMiddleName,
    String? identityLastName,
    String? identityGender,
    String? identityBirthDate,
    String? identityEmail,
    String? identityPhone,
    String? identityAddress1,
    String? identityAddress2,
    String? identityCity,
    String? identityState,
    String? identityPostalCode,
    String? identityCountry,
    String? identityPassportNumber,
    String? identityNationalId,
    String? identityLicenseNumber,
    String? identityCompany,
    String? identityOccupation,
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
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      wifiSecurityType: wifiSecurityType ?? this.wifiSecurityType,
      wifiIsHidden: wifiIsHidden ?? this.wifiIsHidden,
      identityTitle: identityTitle ?? this.identityTitle,
      identityFirstName: identityFirstName ?? this.identityFirstName,
      identityMiddleName: identityMiddleName ?? this.identityMiddleName,
      identityLastName: identityLastName ?? this.identityLastName,
      identityGender: identityGender ?? this.identityGender,
      identityBirthDate: identityBirthDate ?? this.identityBirthDate,
      identityEmail: identityEmail ?? this.identityEmail,
      identityPhone: identityPhone ?? this.identityPhone,
      identityAddress1: identityAddress1 ?? this.identityAddress1,
      identityAddress2: identityAddress2 ?? this.identityAddress2,
      identityCity: identityCity ?? this.identityCity,
      identityState: identityState ?? this.identityState,
      identityPostalCode: identityPostalCode ?? this.identityPostalCode,
      identityCountry: identityCountry ?? this.identityCountry,
      identityPassportNumber: identityPassportNumber ?? this.identityPassportNumber,
      identityNationalId: identityNationalId ?? this.identityNationalId,
      identityLicenseNumber: identityLicenseNumber ?? this.identityLicenseNumber,
      identityCompany: identityCompany ?? this.identityCompany,
      identityOccupation: identityOccupation ?? this.identityOccupation,
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
      'wifiSsid': wifiSsid,
      'wifiPassword': wifiPassword,
      'wifiSecurityType': wifiSecurityType,
      'wifiIsHidden': wifiIsHidden,
      'identityTitle': identityTitle,
      'identityFirstName': identityFirstName,
      'identityMiddleName': identityMiddleName,
      'identityLastName': identityLastName,
      'identityGender': identityGender,
      'identityBirthDate': identityBirthDate,
      'identityEmail': identityEmail,
      'identityPhone': identityPhone,
      'identityAddress1': identityAddress1,
      'identityAddress2': identityAddress2,
      'identityCity': identityCity,
      'identityState': identityState,
      'identityPostalCode': identityPostalCode,
      'identityCountry': identityCountry,
      'identityPassportNumber': identityPassportNumber,
      'identityNationalId': identityNationalId,
      'identityLicenseNumber': identityLicenseNumber,
      'identityCompany': identityCompany,
      'identityOccupation': identityOccupation,
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
        wifiSsid,
        wifiPassword,
        wifiSecurityType,
        wifiIsHidden,
        identityTitle,
        identityFirstName,
        identityMiddleName,
        identityLastName,
        identityGender,
        identityBirthDate,
        identityEmail,
        identityPhone,
        identityAddress1,
        identityAddress2,
        identityCity,
        identityState,
        identityPostalCode,
        identityCountry,
        identityPassportNumber,
        identityNationalId,
        identityLicenseNumber,
        identityCompany,
        identityOccupation,
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

