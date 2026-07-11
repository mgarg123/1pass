import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/vault/providers/vault_provider.dart';
import '../storage/syncing_vault_repository.dart';
import '../config/storage_mode.dart';

enum SyncState {
  synced,
  syncing,
  offline,
  failed,
  disabled, // local-only mode — sync not applicable
}

class SyncNotifier extends Notifier<SyncState> {
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;

  @override
  SyncState build() {
    // If local-only mode, sync is permanently disabled
    final config = ref.read(storageModeProvider);
    if (config == null || config.isLocal) {
      return SyncState.disabled;
    }

    _initConnectivity();
    return SyncState.synced; // default assumption until first check
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    if (!_isOnline) {
      state = SyncState.offline;
    }

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (!_isOnline) {
        state = SyncState.offline;
      } else if (!wasOnline && _isOnline) {
        // Came back online, trigger sync
        triggerSync();
      }
    });
  }

  Future<void> triggerSync() async {
    // Skip sync for local-only mode
    final config = ref.read(storageModeProvider);
    if (config == null || config.isLocal) {
      state = SyncState.disabled;
      return;
    }

    if (!_isOnline) {
      state = SyncState.offline;
      return;
    }

    state = SyncState.syncing;
    try {
      final authState = ref.read(authProvider);
      final key = authState.encryptionKey;
      if (key == null) {
        state = SyncState.synced; // Not logged into vault, nothing to sync yet
        return;
      }

      final repo = ref.read(vaultRepositoryProvider);
      if (repo is SyncingVaultRepository) {
        await repo.sync(key);
        // Inform the vault provider to reload entries from Hive
        ref.invalidate(vaultProvider);
      }
      
      state = SyncState.synced;
    } catch (e) {
      // Sync error ignored silently for security/hygiene
      state = SyncState.failed;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
