import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

class TorrentGalaxyAdapter implements SourceAdapter {
  TorrentGalaxyAdapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;
  static const _mirrors = [
    'https://torrentgalaxy.to',
    'https://torrentgalaxy.mx',
  ];

  @override
  String get id => 'torrent_galaxy';

  @override
  String get displayName => 'Galaxy';

  @override
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    for (final base in _mirrors) {
      try {
        final html = await _client.fetch('$base/torrents.php?search=$encoded');
        var results = parseTorrentGalaxyTable(
          html,
          sourceId: id,
          sourceName: displayName,
          baseUrl: base,
        );
        if (results.isEmpty) continue;

        results = filterMusicResults(results);
        if (results.isEmpty) {
          results = parseTorrentGalaxyTable(
            html,
            sourceId: id,
            sourceName: displayName,
            baseUrl: base,
          ).take(15).toList();
        }

        results = await _client.resolveMagnets(results.take(10).toList(), maxFetches: 3);
        return results.where((r) => r.canDownload).take(25).toList();
      } catch (e, st) {
        debugPrint('TorrentGalaxy scrape failed ($base): $e\n$st');
      }
    }
    return [];
  }
}
