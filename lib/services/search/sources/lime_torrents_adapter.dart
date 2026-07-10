import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

class LimeTorrentsAdapter implements SourceAdapter {
  LimeTorrentsAdapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;
  static const _mirrors = [
    'https://www.limetorrents.lol',
    'https://limetorrents.so',
  ];

  @override
  String get id => 'lime_torrents';

  @override
  String get displayName => 'Lime';

  @override
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    for (final base in _mirrors) {
      try {
        final html = await _client.fetch('$base/search/all/$encoded/seeds/1/');
        var results = parseLimeTable(
          html,
          sourceId: id,
          sourceName: displayName,
          baseUrl: base,
        );
        if (results.isEmpty) continue;

        results = filterMusicResults(results);
        if (results.isEmpty) {
          results = parseLimeTable(
            html,
            sourceId: id,
            sourceName: displayName,
            baseUrl: base,
          ).take(15).toList();
        }

        results = await _client.resolveMagnets(results.take(10).toList(), maxFetches: 3);
        return results.where((r) => r.canDownload).take(25).toList();
      } catch (e, st) {
        debugPrint('LimeTorrents scrape failed ($base): $e\n$st');
      }
    }
    return [];
  }
}
