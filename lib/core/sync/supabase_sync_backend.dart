import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_backend.dart';

/// SyncBackend implementation that uses Supabase PostgREST + Auth.
///
/// This extracts all Supabase-specific data operations that were previously
/// scattered across syncing_vault_repository.dart and auth_provider.dart.
class SupabaseSyncBackend implements SyncBackend {
  final SupabaseClient _client;

  SupabaseSyncBackend(this._client);

  @override
  bool get isReady => _client.auth.currentUser != null;

  String? get _userId => _client.auth.currentUser?.id;

  // ── Vault Meta ──────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getVaultMeta() async {
    final userId = _userId;
    if (userId == null) return null;

    final res = await _client
        .from('user_vault_meta')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return res;
  }

  @override
  Future<void> upsertVaultMeta({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not signed in to Supabase.');

    await _client.from('user_vault_meta').upsert({
      'user_id': userId,
      'salt': salt,
      'argon2_params': argon2Params,
      'verification_blob': verificationBlob,
    });
  }

  // ── Vault Entries ───────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> pullEntries({DateTime? since}) async {
    var query = _client.from('vault_entries').select();
    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }
    final results = await query;
    return List<Map<String, dynamic>>.from(results);
  }

  @override
  Future<void> pushEntries(List<Map<String, dynamic>> entries) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not signed in to Supabase.');

    for (final entry in entries) {
      await _client.from('vault_entries').upsert({
        'id': entry['id'],
        'user_id': userId,
        'encrypted_data': entry['encrypted_data'],
        'nonce': entry['nonce'],
        'created_at': entry['created_at'],
        'updated_at': entry['updated_at'],
        'is_deleted': entry['is_deleted'],
      });
    }
  }

  // ── Master Password Rotation ────────────────────────────────

  @override
  bool get supportsAtomicRotation => true;

  @override
  Future<void> rotateMasterPassword({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
    required List<Map<String, dynamic>> entries,
  }) async {
    await _client.rpc('update_master_password', params: {
      'p_salt': salt,
      'p_argon2_params': argon2Params,
      'p_verification_blob': verificationBlob,
      'p_entries': entries,
    });
  }
}
