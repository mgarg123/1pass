import 'package:dio/dio.dart';
import 'sync_backend.dart';

/// SyncBackend implementation for Bring-Your-Own-DB (BYOD) mode.
///
/// Communicates with a user-provided REST API that implements the
/// OnePass BYOD contract:
///
///   GET    /vault/meta          — Get vault meta
///   PUT    /vault/meta          — Upsert vault meta
///   GET    /vault/entries       — Pull entries (?since=ISO8601)
///   PUT    /vault/entries       — Push/upsert entries
///   POST   /vault/rotate-key   — Atomic password rotation (optional)
///
/// Authentication is via an API key sent as a Bearer token.
class GenericRestSyncBackend implements SyncBackend {
  final String baseUrl;
  final String apiKey;
  late final Dio _dio;

  GenericRestSyncBackend({
    required this.baseUrl,
    required this.apiKey,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  @override
  bool get isReady => apiKey.isNotEmpty && baseUrl.isNotEmpty;

  // ── Vault Meta ──────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getVaultMeta() async {
    try {
      final response = await _dio.get('/vault/meta');
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _wrapError('Failed to get vault meta', e);
    }
  }

  @override
  Future<void> upsertVaultMeta({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
  }) async {
    try {
      await _dio.put('/vault/meta', data: {
        'salt': salt,
        'argon2_params': argon2Params,
        'verification_blob': verificationBlob,
      });
    } on DioException catch (e) {
      throw _wrapError('Failed to upsert vault meta', e);
    }
  }

  // ── Vault Entries ───────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> pullEntries({DateTime? since}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) {
        queryParams['since'] = since.toUtc().toIso8601String();
      }
      final response = await _dio.get('/vault/entries', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _wrapError('Failed to pull entries', e);
    }
  }

  @override
  Future<void> pushEntries(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) return;
    try {
      await _dio.put('/vault/entries', data: {
        'entries': entries,
      });
    } on DioException catch (e) {
      throw _wrapError('Failed to push entries', e);
    }
  }

  // ── Master Password Rotation ────────────────────────────────

  @override
  bool get supportsAtomicRotation => _supportsRotation ?? false;

  bool? _supportsRotation;

  /// Probe the server to check if it supports atomic rotation.
  /// Called once during BYOD setup / connection test.
  Future<void> probeCapabilities() async {
    try {
      final response = await _dio.fetch(RequestOptions(
        path: '/vault/rotate-key',
        method: 'OPTIONS',
        baseUrl: _dio.options.baseUrl,
        headers: _dio.options.headers,
      ));
      _supportsRotation = response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      _supportsRotation = false;
    }
  }

  @override
  Future<void> rotateMasterPassword({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (!supportsAtomicRotation) {
      throw UnsupportedError(
        'This BYOD backend does not support atomic master password rotation. '
        'The client will fall back to entry-by-entry re-encryption.',
      );
    }
    try {
      await _dio.post('/vault/rotate-key', data: {
        'salt': salt,
        'argon2_params': argon2Params,
        'verification_blob': verificationBlob,
        'entries': entries,
      });
    } on DioException catch (e) {
      throw _wrapError('Failed to rotate master password', e);
    }
  }

  // ── Connection Test ─────────────────────────────────────────

  /// Test the connection to the BYOD endpoint.
  /// Returns null on success, or an error message on failure.
  Future<String?> testConnection() async {
    try {
      final response = await _dio.get('/vault/meta');
      if (response.statusCode == 200 || response.statusCode == 404) {
        // Also probe for optional capabilities
        await probeCapabilities();
        return null; // success
      }
      return 'Unexpected response: ${response.statusCode}';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return 'Connection timed out. Check the URL.';
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Authentication failed. Check your API key.';
      }
      return 'Connection failed: ${e.message}';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  Exception _wrapError(String context, DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    if (statusCode != null) {
      return Exception('$context (HTTP $statusCode): $body');
    }
    return Exception('$context: ${e.message}');
  }
}
