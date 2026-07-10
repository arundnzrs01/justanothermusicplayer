import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/data/db/app_database.dart';

class IndexerConfig {
  const IndexerConfig({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.displayName = 'Custom Indexer',
  });

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String displayName;

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  IndexerConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? displayName,
  }) {
    return IndexerConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'displayName': displayName,
      };

  factory IndexerConfig.fromJson(Map<String, dynamic> json) {
    return IndexerConfig(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Custom Indexer',
    );
  }
}

class AppSettings {
  const AppSettings({
    this.wifiOnlyDownloads = false,
    this.downloadLimitKbps = 0,
    this.uploadLimitKbps = 0,
    this.indexer = const IndexerConfig(),
  });

  final bool wifiOnlyDownloads;
  final int downloadLimitKbps;
  final int uploadLimitKbps;
  final IndexerConfig indexer;

  AppSettings copyWith({
    bool? wifiOnlyDownloads,
    int? downloadLimitKbps,
    int? uploadLimitKbps,
    IndexerConfig? indexer,
  }) {
    return AppSettings(
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      downloadLimitKbps: downloadLimitKbps ?? this.downloadLimitKbps,
      uploadLimitKbps: uploadLimitKbps ?? this.uploadLimitKbps,
      indexer: indexer ?? this.indexer,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._db) : super(const AppSettings());

  final AppDatabase _db;

  Future<void> load() async {
    final wifiOnly = await _db.getSetting('wifi_only_downloads');
    final down = await _db.getSetting('download_limit_kbps');
    final up = await _db.getSetting('upload_limit_kbps');
    final indexerJson = await _db.getSetting('indexer_config');

    IndexerConfig indexer = const IndexerConfig();
    if (indexerJson != null && indexerJson.isNotEmpty) {
      indexer = IndexerConfig.fromJson(
        jsonDecode(indexerJson) as Map<String, dynamic>,
      );
    }

    state = AppSettings(
      wifiOnlyDownloads: wifiOnly == 'true',
      downloadLimitKbps: int.tryParse(down ?? '') ?? 0,
      uploadLimitKbps: int.tryParse(up ?? '') ?? 0,
      indexer: indexer,
    );
  }

  Future<void> setWifiOnly(bool value) async {
    state = state.copyWith(wifiOnlyDownloads: value);
    await _db.setSetting('wifi_only_downloads', value.toString());
  }

  Future<void> setSpeedLimits({int? downloadKbps, int? uploadKbps}) async {
    state = state.copyWith(
      downloadLimitKbps: downloadKbps ?? state.downloadLimitKbps,
      uploadLimitKbps: uploadKbps ?? state.uploadLimitKbps,
    );
    if (downloadKbps != null) {
      await _db.setSetting('download_limit_kbps', downloadKbps.toString());
    }
    if (uploadKbps != null) {
      await _db.setSetting('upload_limit_kbps', uploadKbps.toString());
    }
  }

  Future<void> setIndexer(IndexerConfig indexer) async {
    state = state.copyWith(indexer: indexer);
    await _db.setSetting('indexer_config', jsonEncode(indexer.toJson()));
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final notifier = AppSettingsNotifier(ref.watch(databaseProvider));
  notifier.load();
  return notifier;
});
