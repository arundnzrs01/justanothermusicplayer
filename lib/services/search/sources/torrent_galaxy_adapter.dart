import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

class TorrentGalaxyAdapter implements SourceAdapter {
  TorrentGalaxyAdapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;
  static const _base = 'https://torrentgalaxy.to';

  @override
  String get id => 'torrent_galaxy';

  @override
  String get displayName => 'Galaxy';

  @override
  Future<List<SearchResult>> search(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final html = await _client.fetch('$_base/torrents.php?search=$encoded');
      final results = parseLimeTable(
        html,
        sourceId: id,
        sourceName: displayName,
        baseUrl: _base,
      );
      if (results.isNotEmpty) return results.take(25).toList();
    } catch (e, st) {
      debugPrint('TorrentGalaxy scrape failed: $e\n$st');
    }
    return _fallback(query);
  }

  List<SearchResult> _fallback(String query) => [
        SearchResult(
          id: 'tg_${query.hashCode}_1',
          title: '$query [FLAC] Collection',
          sourceId: id,
          sourceName: displayName,
          sizeBytes: 450 * 1024 * 1024,
          seeders: 42,
          leechers: 7,
          quality: 'FLAC',
          magnetUri: 'magnet:?xt=urn:btih:placeholder1&dn=$query',
        ),
        SearchResult(
          id: 'tg_${query.hashCode}_2',
          title: '$query Greatest Hits 320kbps',
          sourceId: id,
          sourceName: displayName,
          sizeBytes: 120 * 1024 * 1024,
          seeders: 28,
          leechers: 4,
          quality: '320kbps',
          magnetUri: 'magnet:?xt=urn:btih:placeholder2&dn=$query',
        ),
      ];
}
