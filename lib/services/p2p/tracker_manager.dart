import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/data/db/app_database.dart';

final trackerManagerProvider = Provider<TrackerManager>((ref) {
  return TrackerManager(ref.watch(databaseProvider));
});

class TrackerManager {
  TrackerManager(this._database);

  final AppDatabase _database;
  final _dio = Dio();
  String listUrl = '';
  List<String> trackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.stealth.si:80/announce',
  ];

  Future<void> load() async {
    listUrl = await _database.getSetting('tracker_list_url') ?? '';
    final stored = await _database.getSetting('tracker_list');
    if (stored != null && stored.isNotEmpty) {
      trackers = stored.split('\n').where((t) => t.trim().isNotEmpty).toList();
    }
  }

  Future<void> setListUrl(String url) async {
    listUrl = url;
    await _database.setSetting('tracker_list_url', url);
  }

  Future<void> saveTrackers(List<String> updated) async {
    trackers = updated.where((t) => t.trim().isNotEmpty).toList();
    await _database.setSetting('tracker_list', trackers.join('\n'));
  }

  Future<void> refreshFromUrl([String? url]) async {
    final target = url ?? listUrl;
    if (target.isEmpty) return;
    listUrl = target;
    await _database.setSetting('tracker_list_url', target);
    final response = await _dio.get<String>(target);
    final lines = response.data
            ?.split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .toList() ??
        [];
    if (lines.isNotEmpty) {
      await saveTrackers(lines);
    }
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
