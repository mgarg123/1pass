import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/crypto/crypto_models.dart';
import '../../../core/storage/hive_setup.dart';

final biometricProvider = NotifierProvider<BiometricNotifier, BiometricState>(BiometricNotifier.new);

class BiometricState {
  final bool isEnabled;
  final bool isSupported;
  
  BiometricState({this.isEnabled = false, this.isSupported = false});
  
  BiometricState copyWith({bool? isEnabled, bool? isSupported}) {
    return BiometricState(
      isEnabled: isEnabled ?? this.isEnabled,
      isSupported: isSupported ?? this.isSupported,
    );
  }
}

class BiometricNotifier extends Notifier<BiometricState> {
  final _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  
  static const _keyStoreName = 'biometric_derived_key';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _lastMasterPasswordTimeKey = 'last_master_password_time';
  
  @override
  BiometricState build() {
    final isEnabled = HiveSetup.metaBox.get(_biometricEnabledKey, defaultValue: false) as bool;
    Future.microtask(_checkSupport);
    return BiometricState(isEnabled: isEnabled);
  }
  
  Future<void> _checkSupport() async {
    if (kIsWeb) return;
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      state = state.copyWith(isSupported: isSupported);
    } catch (_) {}
  }
  
  Future<void> setEnabled(bool enabled, EncryptionKey? currentKey) async {
    if (enabled) {
        final canCheck = await _localAuth.canCheckBiometrics;
        if (!canCheck) {
            throw Exception("No biometrics enrolled on this device.");
        }
        
        try {
            final authenticated = await _localAuth.authenticate(
                localizedReason: 'Please authenticate to enable biometric unlock',
                biometricOnly: true,
                persistAcrossBackgrounding: true,
            );
            
            if (!authenticated) {
                throw Exception("Biometric authentication failed.");
            }
        } on PlatformException catch (e) {
             throw Exception("Biometric error: ${e.message}");
        }
        
        if (currentKey != null) {
            final base64Key = base64Encode(currentKey.bytes);
            await _secureStorage.write(key: _keyStoreName, value: base64Key);
            await recordMasterPasswordLogin();
        }
    } else {
        await _secureStorage.delete(key: _keyStoreName);
    }
    
    await HiveSetup.metaBox.put(_biometricEnabledKey, enabled);
    state = state.copyWith(isEnabled: enabled);
  }
  
  Future<void> storeEncryptionKey(EncryptionKey key) async {
     if (!state.isEnabled) return;
     final base64Key = base64Encode(key.bytes);
     await _secureStorage.write(key: _keyStoreName, value: base64Key);
     await recordMasterPasswordLogin();
  }
  
  Future<void> recordMasterPasswordLogin() async {
      await HiveSetup.metaBox.put(_lastMasterPasswordTimeKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  bool isMasterPasswordRequired() {
      final lastLoginMs = HiveSetup.metaBox.get(_lastMasterPasswordTimeKey) as int?;
      if (lastLoginMs == null) return true;
      
      final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
      final daysSince = DateTime.now().difference(lastLogin).inDays;
      
      return daysSince >= 7;
  }
  
  Future<EncryptionKey?> unlockWithBiometrics() async {
      if (!state.isEnabled || isMasterPasswordRequired()) {
          return null; // Master password is required
      }
      
      try {
          final authenticated = await _localAuth.authenticate(
              localizedReason: 'Unlock your vault',
              biometricOnly: true,
              persistAcrossBackgrounding: true,
          );
          
          if (!authenticated) {
              return null;
          }
          
          final base64Key = await _secureStorage.read(key: _keyStoreName);
          if (base64Key == null) {
              return null; 
          }
          
          return EncryptionKey(base64Decode(base64Key));
      } catch (e) {
          // If biometric enrollment changed, it might throw here, or fail auth.
          // In any case, we fallback to master password by returning null.
          return null;
      }
  }
  
  Future<void> clearStoredKey() async {
      // Just clear from secure storage without changing the toggle.
      // (Used when we logout entirely or change password without re-enabling)
      await _secureStorage.delete(key: _keyStoreName);
  }
}
