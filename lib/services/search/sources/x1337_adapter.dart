import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

/// 1337x HTML scraper with mirror fallback.
class X1337Adapter implements SourceAdapter {
  X1337Adapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;

  static const _mirrors = [
    'https://1337x.to',
    'https://www.1337x.tw',
    'https://1337x.st',
  ];

  @override
  String get id => '1337x';

  @override
  String get displayName => '1337x';

  @override
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    for (final base in _mirrors) {
      try {
        final html = await _client.fetch('$base/search/$encoded/1/');
        var results = parse1337xTable(
          html,
          sourceId: id,
          sourceName: displayName,
          baseUrl: base,
        );
        if (results.isEmpty) continue;

        results = filterMusicResults(results);
        if (results.isEmpty) {
          results = parse1337xTable(
            html,
            sourceId: id,
            sourceName: displayName,
            baseUrl: base,
          ).take(15).toList();
        }

        results = await _client.resolveMagnets(results.take(15).toList());
        return results.where((r) => r.effectiveMagnet != null).take(25).toList();
      } catch (e, st) {
        debugPrint('1337x mirror $base failed: $e\n$st');
      }
    }
    return [];
  }
}
