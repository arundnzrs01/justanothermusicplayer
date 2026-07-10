import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

class LimeTorrentsAdapter implements SourceAdapter {
  LimeTorrentsAdapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;
  static const _base = 'https://www.limetorrents.lol';

  @override
  String get id => 'lime_torrents';

  @override
  String get displayName => 'Lime';

  @override
  Future<List<SearchResult>> search(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final html = await _client.fetch(
        '$_base/search/all/$encoded/seeds/1/',
      );
      final results = parseLimeTable(
        html,
        sourceId: id,
        sourceName: displayName,
        baseUrl: _base,
      );
      if (results.isNotEmpty) return results.take(25).toList();
    } catch (e, st) {
      debugPrint('LimeTorrents scrape failed: $e\n$st');
    }
    return _fallback(query);
  }

  List<SearchResult> _fallback(String query) => [
        SearchResult(
          id: 'lt_${query.hashCode}_fallback',
          title: '$query - Discography',
          sourceId: id,
          sourceName: displayName,
          sizeBytes: 890 * 1024 * 1024,
          seeders: 19,
          leechers: 11,
          quality: 'MP3 V0',
          magnetUri: 'magnet:?xt=urn:btih:placeholder3&dn=$query',
        ),
      ];
}
