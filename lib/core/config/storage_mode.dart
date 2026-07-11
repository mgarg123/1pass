import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/hive_setup.dart';

enum StorageMode {
  localOnly,
  cloudSync,
  byodSync,
}

class StorageModeConfig {
  final StorageMode mode;
  final String? byodUrl;
  final String? byodApiKey;

  StorageModeConfig({
    required this.mode,
    this.byodUrl,
    this.byodApiKey,
  });

  bool get isSyncEnabled => mode != StorageMode.localOnly;
  bool get isCloud => mode == StorageMode.cloudSync;
  bool get isByod => mode == StorageMode.byodSync;
  bool get isLocal => mode == StorageMode.localOnly;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'byodUrl': byodUrl,
    'byodApiKey': byodApiKey,
  };

  factory StorageModeConfig.fromJson(Map<String, dynamic> json) {
    return StorageModeConfig(
      mode: StorageMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => StorageMode.localOnly,
      ),
      byodUrl: json['byodUrl'] as String?,
      byodApiKey: json['byodApiKey'] as String?,
    );
  }

  static StorageModeConfig? load() {
    final data = HiveSetup.configBox.get('storage_mode_config');
    if (data == null) return null;
    return StorageModeConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> save() async {
    await HiveSetup.configBox.put('storage_mode_config', toJson());
  }

  StorageModeConfig copyWith({
    StorageMode? mode,
    String? byodUrl,
    String? byodApiKey,
    bool clearByod = false,
  }) {
    return StorageModeConfig(
      mode: mode ?? this.mode,
      byodUrl: clearByod ? null : (byodUrl ?? this.byodUrl),
      byodApiKey: clearByod ? null : (byodApiKey ?? this.byodApiKey),
    );
  }
}

class StorageModeNotifier extends Notifier<StorageModeConfig?> {
  @override
  StorageModeConfig? build() {
    return StorageModeConfig.load();
  }

  Future<void> setMode(StorageModeConfig config) async {
    await config.save();
    state = config;
  }

  Future<void> clear() async {
    await HiveSetup.configBox.delete('storage_mode_config');
    state = null;
  }
}

final storageModeProvider = NotifierProvider<StorageModeNotifier, StorageModeConfig?>(
  StorageModeNotifier.new,
);
