import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crypto/crypto_models.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/storage/vault_repository.dart';

final cryptoServiceProvider = Provider((ref) => CryptoService());

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  return HiveVaultRepository(cryptoService);
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
    final salt = await _vaultRepository.getSalt();
    return salt != null;
  }

  Future<void> signup(String masterPassword) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final salt = await _cryptoService.generateSalt();
      final key = await _cryptoService.deriveKey(password: masterPassword, salt: salt);
      
      // Store salt and initialize empty vault
      await _vaultRepository.clearVault();
      await _vaultRepository.saveSalt(salt);
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString());
    }
  }

  Future<void> login(String masterPassword) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final salt = await _vaultRepository.getSalt();
      if (salt == null) {
        throw Exception('No account found. Please sign up first.');
      }
      
      final key = await _cryptoService.deriveKey(password: masterPassword, salt: salt);
      
      // Verify key by attempting to decrypt the vault
      try {
         await _vaultRepository.getAllEntries(key);
      } on DecryptionFailedException {
         key.clear();
         throw Exception('Incorrect master password');
      }
      
      state = state.copyWith(encryptionKey: key, isAuthenticating: false);
    } catch (e) {
      state = state.copyWith(isAuthenticating: false, errorMessage: e.toString());
    }
  }

  void logout() {
    state.encryptionKey?.clear();
    state = state.copyWith(clearKey: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// A simple provider to determine if the user has an existing account (salt stored)
final hasAccountProvider = FutureProvider<bool>((ref) async {
  final authNotifier = ref.watch(authProvider.notifier);
  return authNotifier.hasStoredSalt();
});
