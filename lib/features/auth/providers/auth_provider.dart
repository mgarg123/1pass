import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_models.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/constants/crypto_constants.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/storage/syncing_vault_repository.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/sync/sync_backend.dart';
import '../../../core/sync/supabase_sync_backend.dart';
import '../../../core/sync/generic_rest_sync_backend.dart';
import '../../../core/storage/hive_setup.dart';
import '../../../core/config/storage_mode.dart';
import 'biometric_provider.dart';

final cryptoServiceProvider = Provider((ref) => CryptoService());

/// Provides the appropriate SyncBackend based on the current storage mode.
/// Returns null for local-only mode (no sync needed).
final syncBackendProvider = Provider<SyncBackend?>((ref) {
  final config = ref.watch(storageModeProvider);
  if (config == null) return null;

  switch (config.mode) {
    case StorageMode.localOnly:
      return null;
    case StorageMode.cloudSync:
      return SupabaseSyncBackend(Supabase.instance.client);
    case StorageMode.byodSync:
      if (config.byodUrl == null || config.byodApiKey == null) return null;
      return GenericRestSyncBackend(
        baseUrl: config.byodUrl!,
        apiKey: config.byodApiKey!,
      );
  }
});

/// Provides the VaultRepository — either local-only or syncing,
/// depending on the current storage mode.
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  final localRepo = HiveVaultRepository(cryptoService);
  final syncBackend = ref.watch(syncBackendProvider);

  if (syncBackend == null) {
    return localRepo; // local-only mode
  }
  return SyncingVaultRepository(localRepo, cryptoService, syncBackend);
});

class AuthState {
  final EncryptionKey? encryptionKey;
  final bool isAuthenticating;
  final String? errorMessage;
  
  bool get isAuthenticated => encryptionKey != null;

  AuthState({this.encryptionKey, this.isAuthenticating = false, this.errorMessage});
  
  AuthState copyWith({
    EncryptionKey? encryptionKey,
    bool clearKey = false,
    bool? isAuthenticating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      encryptionKey: clearKey ? null : (encryptionKey ?? this.encryptionKey),
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  CryptoService get _cryptoService => ref.read(cryptoServiceProvider);
  VaultRepository get _vaultRepository => ref.read(vaultRepositoryProvider);
  SyncBackend? get _syncBackend => ref.read(syncBackendProvider);
  StorageModeConfig? get _modeConfig => ref.read(storageModeProvider);

  @override
  AuthState build() {
    return AuthState();
  }

  Future<bool> hasStoredSalt() async {
    final meta = await _vaultRepository.getMeta();
    return meta != null;
  }
  
  /// Whether the remote auth layer is satisfied.
  /// - Local-only: always true (no remote auth needed)
  /// - Cloud sync: true if Supabase session exists
  /// - BYOD: true if API key is configured
  bool get isRemoteAuthenticated {
    final config = _modeConfig;
    if (config == null) return false; // no mode selected yet

    switch (config.mode) {
      case StorageMode.localOnly:
        return true;
      case StorageMode.cloudSync:
        return Supabase.instance.client.auth.currentUser != null;
      case StorageMode.byodSync:
        return config.byodApiKey != null && config.byodApiKey!.isNotEmpty;
    }
  }

  // ── Supabase Auth (cloud sync mode only) ────────────────────

  Future<void> supabaseSignUp(String email, String password) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final res = await Supabase.instance.client.auth.signUp(email: email, password: password);
      if (res.session == null) {
        state = state.copyWith(
          isAuthenticating: false, 
          errorMessage: 'Signup successful! Please check your email to confirm your account.',
        );
      } else {
        state = state.copyWith(isAuthenticating: false);
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains('user already registered')) {
        msg = 'An account with this email already exists. Please sign in instead.';
      }
      state = state.copyWith(isAuthenticating: false, errorMessage: msg);
      rethrow;
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: 'An unexpected error occurred: $e');
      rethrow;
    }
  }

  Future<void> supabaseSignIn(String email, String password) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      state = state.copyWith(isAuthenticating: false);
    } on AuthException catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: 'An unexpected error occurred: $e');
      rethrow;
    }
  }

  // ── Vault Setup & Unlock (all modes) ────────────────────────

  Future<void> setupVault(String masterPassword) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final salt = await _cryptoService.generateSalt();
      final key = await _cryptoService.deriveKey(password: masterPassword, salt: salt);
      
      final params = Argon2Params(
        memoryKB: CryptoConstants.argon2MemoryKB,
        iterations: CryptoConstants.argon2Iterations,
        parallelism: CryptoConstants.argon2Parallelism,
        hashLengthBytes: CryptoConstants.keyLengthBytes,
      );

      final verificationPayload = Uint8List.fromList(utf8.encode('vault-verify'));
      final verificationBlobObj = await _cryptoService.encrypt(verificationPayload, key);
      final verificationBlobStr = verificationBlobObj.toStorageString();

      // Store salt and initialize empty vault
      await _vaultRepository.clearVault();
      await _vaultRepository.saveMeta(salt, params, verificationBlobStr);
      
      // Upload meta to remote backend if sync is enabled
      final backend = _syncBackend;
      if (backend != null && backend.isReady) {
        await backend.upsertVaultMeta(
          salt: salt.toBase64(),
          argon2Params: params.toJson(),
          verificationBlob: verificationBlobStr,
        );
      }
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> unlockVault(String masterPassword) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      LocalUserMeta? meta = await _vaultRepository.getMeta();
      
      // If no local meta, try fetching from remote backend
      if (meta == null) {
        final backend = _syncBackend;
        if (backend != null && backend.isReady) {
          final remoteMeta = await backend.getVaultMeta();

          if (remoteMeta == null) {
            throw Exception('No vault setup found. Please set up your vault.');
          }

          final salt = Salt.fromBase64(remoteMeta['salt'] as String);
          final params = Argon2Params.fromJson(
            Map<String, dynamic>.from(remoteMeta['argon2_params'] as Map),
          );
          final verificationBlob = remoteMeta['verification_blob'] as String;

          await _vaultRepository.saveMeta(salt, params, verificationBlob);
          meta = LocalUserMeta(salt: salt, argon2Params: params, verificationBlob: verificationBlob);
        } else if (_modeConfig?.isLocal == true) {
          throw Exception('No vault setup found. Please set up your vault.');
        } else {
          throw Exception('No vault setup found and remote backend is not available.');
        }
      }
      
      final key = await _cryptoService.deriveKey(password: masterPassword, salt: meta.salt);
      
      if (meta.verificationBlob != null && meta.verificationBlob!.isNotEmpty) {
          final blob = EncryptedBlob.fromStorageString(meta.verificationBlob!);
          try {
             final dec = await _cryptoService.decrypt(blob, key);
             if (utf8.decode(dec) != 'vault-verify') {
                 throw Exception('Incorrect master password');
             }
          } catch (e) {
             key.clear();
             throw Exception('Incorrect master password');
          }
      } else {
          // Fallback for older vaults
          try {
             await _vaultRepository.getAllEntries(key);
          } on DecryptionFailedException {
             key.clear();
             throw Exception('Incorrect master password');
          }
      }
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);
      
      ref.read(biometricProvider.notifier).storeEncryptionKey(key);

      // Only trigger sync if we have a sync backend
      if (_syncBackend != null) {
        ref.read(syncProvider.notifier).triggerSync();
      }
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> lockVault() async {
    state.encryptionKey?.clear();
    state = state.copyWith(clearKey: true);
  }

  Future<void> logout() async {
    state.encryptionKey?.clear();
    await ref.read(biometricProvider.notifier).clearStoredKey();

    // Sign out of Supabase only in cloud sync mode
    if (_modeConfig?.isCloud == true) {
      await Supabase.instance.client.auth.signOut();
    }

    state = state.copyWith(clearKey: true);
  }

  Future<void> unlockWithBiometrics() async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final key = await ref.read(biometricProvider.notifier).unlockWithBiometrics();
      if (key == null) {
        state = state.copyWith(
          isAuthenticating: false, 
          errorMessage: 'Biometric unlock failed or expired. Please use master password.'
        );
        return;
      }
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);

      if (_syncBackend != null) {
        ref.read(syncProvider.notifier).triggerSync();
      }
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      LocalUserMeta? meta = await _vaultRepository.getMeta();
      if (meta == null) throw Exception('No local vault found.');

      // 1. Verify current password
      final oldKey = await _cryptoService.deriveKey(password: currentPassword, salt: meta.salt);
      if (meta.verificationBlob != null && meta.verificationBlob!.isNotEmpty) {
        final blob = EncryptedBlob.fromStorageString(meta.verificationBlob!);
        try {
          final dec = await _cryptoService.decrypt(blob, oldKey);
          if (utf8.decode(dec) != 'vault-verify') throw Exception();
        } catch (_) {
          oldKey.clear();
          throw Exception('Incorrect current master password.');
        }
      }

      // 2. Generate new salt, derive new key
      final newSalt = await _cryptoService.generateSalt();
      final newKey = await _cryptoService.deriveKey(password: newPassword, salt: newSalt);
      final params = Argon2Params(
        memoryKB: CryptoConstants.argon2MemoryKB,
        iterations: CryptoConstants.argon2Iterations,
        parallelism: CryptoConstants.argon2Parallelism,
        hashLengthBytes: CryptoConstants.keyLengthBytes,
      );

      // 3. Generate new verification blob
      final verificationPayload = Uint8List.fromList(utf8.encode('vault-verify'));
      final newVerificationBlobObj = await _cryptoService.encrypt(verificationPayload, newKey);
      final newVerificationBlobStr = newVerificationBlobObj.toStorageString();

      // 4. Decrypt and re-encrypt entries
      final entries = await _vaultRepository.getAllEntries(oldKey);
      final rpcEntries = <Map<String, dynamic>>[];
      
      for (final entry in entries) {
        final payloadString = entry.sensitivePayload;
        final payloadBytes = Uint8List.fromList(utf8.encode(payloadString));
        final newBlob = await _cryptoService.encrypt(payloadBytes, newKey);
        
        DateTime newUpdatedAt = DateTime.now().toUtc();
        if (!newUpdatedAt.isAfter(entry.updatedAt)) {
            newUpdatedAt = entry.updatedAt.add(const Duration(milliseconds: 1));
        }

        rpcEntries.add({
          'id': entry.id,
          'encryptedData': newBlob.toStorageString(),
          'updatedAt': newUpdatedAt.toIso8601String(),
        });
      }

      // 5. Upload to remote backend (if available)
      final backend = _syncBackend;
      if (backend != null && backend.isReady) {
        if (backend.supportsAtomicRotation) {
          // Atomic rotation via server-side transaction
          await backend.rotateMasterPassword(
            salt: newSalt.toBase64(),
            argon2Params: params.toJson(),
            verificationBlob: newVerificationBlobStr,
            entries: rpcEntries,
          );
        } else {
          // Fallback: update meta first, then push entries one by one
          await backend.upsertVaultMeta(
            salt: newSalt.toBase64(),
            argon2Params: params.toJson(),
            verificationBlob: newVerificationBlobStr,
          );
          // Push re-encrypted entries
          final pushEntries = <Map<String, dynamic>>[];
          for (int i = 0; i < entries.length; i++) {
            final entry = entries[i];
            final rpcEntry = rpcEntries[i];
            final blob = EncryptedBlob.fromStorageString(rpcEntry['encryptedData']);
            pushEntries.add({
              'id': entry.id,
              'encrypted_data': rpcEntry['encryptedData'],
              'nonce': blob.nonce.toBase64(),
              'created_at': entry.createdAt.toIso8601String(),
              'updated_at': rpcEntry['updatedAt'],
              'is_deleted': entry.isDeleted,
            });
          }
          if (pushEntries.isNotEmpty) {
            await backend.pushEntries(pushEntries);
          }
        }
      }

      // 6. Local commit
      await _vaultRepository.saveMeta(newSalt, params, newVerificationBlobStr);
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final rpcEntry = rpcEntries[i];
        
        final updatedEntry = entry.copyWith(updatedAt: DateTime.parse(rpcEntry['updatedAt']));
        
        final data = {
          'id': updatedEntry.id,
          'title': updatedEntry.title,
          'tags': updatedEntry.tags,
          'createdAt': updatedEntry.createdAt.toIso8601String(),
          'updatedAt': updatedEntry.updatedAt.toIso8601String(),
          'isDeleted': updatedEntry.isDeleted,
          'encryptedData': rpcEntry['encryptedData'],
        };
        await HiveSetup.vaultBox.put(updatedEntry.id, data);
      }
      
      // Clear old key
      state.encryptionKey?.clear();
      oldKey.clear();
      
      // Set new state
      state = state.copyWith(encryptionKey: newKey, isAuthenticating: false);
      ref.read(biometricProvider.notifier).storeEncryptionKey(newKey);
      
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// A simple provider to determine if the user has an existing account (salt stored)
final hasAccountProvider = FutureProvider<bool>((ref) async {
  final authNotifier = ref.watch(authProvider.notifier);
  
  // 1. Check local vault meta
  if (await authNotifier.hasStoredSalt()) {
    return true;
  }

  // 2. Check remote backend for existing vault meta (first login on new device)
  final syncBackend = ref.read(syncBackendProvider);
  if (syncBackend != null && syncBackend.isReady) {
    try {
      final remoteMeta = await syncBackend.getVaultMeta();
      if (remoteMeta != null) {
        return true;
      }
    } catch (_) {
      // Fallback to false if network error
    }
  }

  return false;
});
