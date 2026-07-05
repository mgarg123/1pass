import 'dart:convert';
import 'package:equatable/equatable.dart';

class VaultEntry extends Equatable {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  VaultEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes sensitive fields to a JSON string for encryption.
  String get sensitivePayload {
    return jsonEncode({
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
    });
  }

  @override
  List<Object?> get props => [
        id,
        title,
        username,
        password,
        url,
        notes,
        tags,
        createdAt,
        updatedAt,
      ];
}
