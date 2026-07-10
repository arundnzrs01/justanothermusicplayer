import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/services/p2p/tracker_list_config.dart';

final trackerManagerProvider = Provider<TrackerManager>((ref) {
  return TrackerManager(ref.watch(databaseProvider));
});

class TrackerManager {
  TrackerManager(this._database);

  final AppDatabase _database;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'JAMP/1.0'},
  ));

  String listUrl = TrackerListConfig.defaultListUrl;
  List<String> trackers = [];
  DateTime? lastUpdatedAt;

  Future<void> load() async {
    listUrl = await _database.getSetting('tracker_list_url') ?? '';
    if (listUrl.isEmpty) {
      listUrl = TrackerListConfig.defaultListUrl;
      await _database.setSetting('tracker_list_url', listUrl);
    }

    final updatedAt = await _database.getSetting('tracker_list_updated_at');
    lastUpdatedAt = updatedAt != null ? DateTime.tryParse(updatedAt) : null;

    final stored = await _database.getSetting('tracker_list');
    if (stored != null && stored.isNotEmpty) {
      trackers = _parseLines(stored);
      return;
    }

    await refreshFromUrl(listUrl);
  }

  Future<void> setListUrl(String url) async {
    listUrl = url;
    await _database.setSetting('tracker_list_url', url);
  }

  Future<void> saveTrackers(List<String> updated) async {
    trackers = updated.where((t) => t.trim().isNotEmpty).toList();
    await _database.setSetting('tracker_list', trackers.join('\n'));
    lastUpdatedAt = DateTime.now();
    await _database.setSetting(
      'tracker_list_updated_at',
      lastUpdatedAt!.toIso8601String(),
    );
  }

  Future<bool> refreshFromUrl([String? url]) async {
    final target = url ?? listUrl;
    if (target.isEmpty) return false;

    try {
      listUrl = target;
      await _database.setSetting('tracker_list_url', target);
      final response = await _dio.get<String>(target);
      final lines = _parseLines(response.data ?? '');
      if (lines.isEmpty) return false;

      trackers = lines;
      await _database.setSetting('tracker_list', trackers.join('\n'));
      lastUpdatedAt = DateTime.now();
      await _database.setSetting(
        'tracker_list_updated_at',
        lastUpdatedAt!.toIso8601String(),
      );
      return true;
    } catch (e, st) {
      debugPrint('Tracker refresh failed: $e\n$st');
      return false;
    }
  }

  /// Refreshes from [listUrl] when auto-update is on and the list is stale.
  Future<bool> maybeAutoRefresh({required bool enabled, bool force = false}) async {
    if (!enabled && !force) return false;

    if (!force && lastUpdatedAt != null) {
      final age = DateTime.now().difference(lastUpdatedAt!);
      if (age < TrackerListConfig.autoUpdateInterval) return false;
    }

    return refreshFromUrl(listUrl);
  }

  List<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
  }

  Future<List<String>> getPerDownloadTrackers(String downloadId) async {
    final stored = await _database.getSetting('dl_trackers_$downloadId');
    if (stored == null || stored.isEmpty) return List.of(trackers);
    return stored.split('\n').where((t) => t.trim().isNotEmpty).toList();
  }

  Future<void> savePerDownloadTrackers(
    String downloadId,
    List<String> updated,
  ) async {
    await _database.setSetting(
      'dl_trackers_$downloadId',
      updated.join('\n'),
    );
  }
}
