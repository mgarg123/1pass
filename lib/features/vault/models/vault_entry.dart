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
  final List<String> tags;
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
    required this.tags,
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
    List<String>? tags,
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
      tags: tags ?? this.tags,
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
      'tags': tags,
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
        tags,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
