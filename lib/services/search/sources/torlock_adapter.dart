import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

/// Torlock music-category scraper.
class TorlockAdapter implements SourceAdapter {
  TorlockAdapter({ScrapeClient? client}) : _client = client ?? ScrapeClient();

  final ScrapeClient _client;
  static const _base = 'https://www.torlock.com';

  @override
  String get id => 'torlock';

  @override
  String get displayName => 'Torlock';

  @override
  Future<List<SearchResult>> search(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final html = await _client.fetch('$_base/music/$encoded.html');
      final document = html_parser.parse(html);
      final results = <SearchResult>[];

      for (final row in document.querySelectorAll('table.table tr')) {
        final link = row.querySelector('a[href*="/torrent/"]');
        if (link == null) continue;
        final title = link.text.trim();
        if (title.isEmpty) continue;

        final href = link.attributes['href'] ?? '';
        final detailUrl = href.startsWith('http') ? href : '$_base$href';
        final magnet = row.querySelector('a[href^="magnet:"]')?.attributes['href'];
        final cells = row.querySelectorAll('td');

        results.add(
          SearchResult(
            id: 'torlock_${title.hashCode}',
            title: title,
            sourceId: id,
            sourceName: displayName,
            sizeBytes: cells.length > 3 ? parseSizeToBytes(cells[3].text) : 0,
            seeders: cells.length > 4 ? parseIntLoose(cells[4].text) : 0,
            leechers: cells.length > 5 ? parseIntLoose(cells[5].text) : 0,
            magnetUri: magnet,
            detailUrl: magnet == null ? detailUrl : null,
          ),
        );
      }

      if (results.isEmpty) return [];
      final resolved = await _client.resolveMagnets(results.take(15).toList());
      return resolved.where((r) => r.effectiveMagnet != null).take(25).toList();
    } catch (e, st) {
      debugPrint('Torlock search failed: $e\n$st');
      return [];
    }
  }
}
