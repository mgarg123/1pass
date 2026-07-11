/// Abstract interface for remote sync backends.
///
/// Any backend (Supabase, BYOD REST API, etc.) must implement
/// the 4 required operations. The atomic master password rotation
/// is optional — backends that don't support it should return false
/// from [supportsAtomicRotation] and the client will fall back to
/// entry-by-entry re-encryption.
abstract class SyncBackend {
  /// Whether the backend is authenticated and ready to perform operations.
  bool get isReady;

  // ── Vault Meta ──────────────────────────────────────────────

  /// Get vault meta (salt, argon2_params, verification_blob) for the
  /// current user. Returns null if no meta exists.
  Future<Map<String, dynamic>?> getVaultMeta();

  /// Create or update vault meta for the current user.
  Future<void> upsertVaultMeta({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
  });

  // ── Vault Entries ───────────────────────────────────────────

  /// Pull all entries updated after [since]. If [since] is null,
  /// pull all entries.
  ///
  /// Each entry map must contain:
  /// - `id` (String)
  /// - `encrypted_data` (String) — the EncryptedBlob storage string
  /// - `nonce` (String) — base64 nonce
  /// - `created_at` (String) — ISO 8601
  /// - `updated_at` (String) — ISO 8601
  /// - `is_deleted` (bool)
  Future<List<Map<String, dynamic>>> pullEntries({DateTime? since});

  /// Push/upsert entries to the remote backend.
  ///
  /// Each entry map must contain the same fields as [pullEntries] output.
  Future<void> pushEntries(List<Map<String, dynamic>> entries);

  // ── Master Password Rotation (Optional) ─────────────────────

  /// Whether this backend supports atomic master password rotation
  /// via a single server-side transaction.
  bool get supportsAtomicRotation;

  /// Atomically rotate the master password on the server.
  /// Only called if [supportsAtomicRotation] is true.
  ///
  /// Implementations should update vault meta AND re-encrypted entries
  /// in a single transaction.
  Future<void> rotateMasterPassword({
    required String salt,
    required Map<String, dynamic> argon2Params,
    required String verificationBlob,
    required List<Map<String, dynamic>> entries,
  });
}
