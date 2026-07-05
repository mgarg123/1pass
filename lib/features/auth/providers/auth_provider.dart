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

final cryptoServiceProvider = Provider((ref) => CryptoService());

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  final localRepo = HiveVaultRepository(cryptoService);
  return SyncingVaultRepository(localRepo, cryptoService, Supabase.instance.client);
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

  @override
  AuthState build() {
    return AuthState();
  }

  Future<bool> hasStoredSalt() async {
    final meta = await _vaultRepository.getMeta();
    return meta != null;
  }
  
  bool get isSupabaseAuthenticated => Supabase.instance.client.auth.currentUser != null;

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
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
          await Supabase.instance.client.from('user_vault_meta').upsert({
            'user_id': userId,
            'salt': salt.toBase64(),
            'argon2_params': params.toJson(),
            'verification_blob': verificationBlobStr,
          });
      }
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString());
    }
  }

  Future<void> unlockVault(String masterPassword) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      LocalUserMeta? meta = await _vaultRepository.getMeta();
      
      if (meta == null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
            throw Exception('Please sign in to Supabase first.');
        }

        final res = await Supabase.instance.client
            .from('user_vault_meta')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (res == null) {
          throw Exception('No vault setup found for this user. Please set up your vault.');
        }

        final salt = Salt.fromBase64(res['salt'] as String);
        final params = Argon2Params.fromJson(res['argon2_params'] as Map<String, dynamic>);
        final verificationBlob = res['verification_blob'] as String;

        await _vaultRepository.saveMeta(salt, params, verificationBlob);
        meta = LocalUserMeta(salt: salt, argon2Params: params, verificationBlob: verificationBlob);
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
      
      ref.read(syncProvider.notifier).triggerSync();
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state.encryptionKey?.clear();
    await Supabase.instance.client.auth.signOut();
    state = state.copyWith(clearKey: true);
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

  // 2. Check Supabase for existing vault meta (first login on new device)
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    try {
      final res = await Supabase.instance.client
          .from('user_vault_meta')
          .select('user_id') // We only need to check if it exists
          .eq('user_id', userId)
          .maybeSingle();
          
      if (res != null) {
        return true;
      }
    } catch (_) {
      // Fallback to false if network error, though unlock will also fail if offline and no local DB
    }
  }

  return false;
});
