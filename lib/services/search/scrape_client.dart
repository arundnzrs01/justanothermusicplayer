import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/magnet_utils.dart';

/// Shared HTTP client for indexer HTML scraping.
class ScrapeClient {
  ScrapeClient() : _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        followRedirects: true,
        maxRedirects: 5,
      ));

  final Dio _dio;

  Future<String> fetch(String url) async {
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }

  Future<String?> fetchMagnetFromPage(String pageUrl) async {
    try {
      final html = await fetch(pageUrl);
      return extractMagnetFromHtml(html);
    } catch (_) {
      return null;
    }
  }

  Future<List<SearchResult>> resolveMagnets(
    List<SearchResult> results, {
    int maxFetches = 5,
  }) async {
    final resolved = <SearchResult>[];
    final toFetch = <SearchResult>[];

    for (final result in results) {
      if (result.magnetUri != null || result.infoHash != null) {
        resolved.add(result);
      } else if (result.detailUrl != null && toFetch.length < maxFetches) {
        toFetch.add(result);
      } else {
        resolved.add(result);
      }
    }

    if (toFetch.isEmpty) return resolved;

    final fetched = await Future.wait(
      toFetch.map((result) async {
        final magnet = await fetchMagnetFromPage(result.detailUrl!);
        return SearchResult(
          id: result.id,
          title: result.title,
          sourceId: result.sourceId,
          sourceName: result.sourceName,
          sizeBytes: result.sizeBytes,
          seeders: result.seeders,
          leechers: result.leechers,
          quality: result.quality,
          date: result.date,
          magnetUri: magnet,
          infoHash: result.infoHash,
          detailUrl: result.detailUrl,
        );
      }),
    );

    return [...resolved, ...fetched];
  }

  Future<String?> resolveMagnetForResult(SearchResult result) async {
    if (result.effectiveMagnet != null) return result.effectiveMagnet;
    final pageUrl = result.detailUrl;
    if (pageUrl == null) return null;
    return fetchMagnetFromPage(pageUrl);
  }
}

int parseSizeToBytes(String raw) {
  final text = raw.trim().toUpperCase();
  final match = RegExp(r'([\d.]+)\s*(GB|MB|KB|TB|B)').firstMatch(text);
  if (match == null) return 0;
  final value = double.tryParse(match.group(1)!) ?? 0;
  return switch (match.group(2)) {
    'TB' => (value * 1024 * 1024 * 1024 * 1024).round(),
    'GB' => (value * 1024 * 1024 * 1024).round(),
    'MB' => (value * 1024 * 1024).round(),
    'KB' => (value * 1024).round(),
    _ => value.round(),
  };
}

int parseIntLoose(String? text) => int.tryParse(text?.replaceAll(',', '') ?? '') ?? 0;

List<SearchResult> parseLimeTable(
  String html, {
  required String sourceId,
  required String sourceName,
  required String baseUrl,
}) {
  final document = html_parser.parse(html);
  final rows = document.querySelectorAll('table.table2 tr');
  final results = <SearchResult>[];

  for (final row in rows) {
    final link = row.querySelector('a[href*="/torrent/"]');
    if (link == null) continue;

    final title = link.text.trim();
    if (title.isEmpty) continue;

    final href = link.attributes['href'] ?? '';
    final detailUrl = href.startsWith('http') ? href : '$baseUrl$href';
    final cells = row.querySelectorAll('td');
    if (cells.length < 4) continue;

    final sizeText = cells.length > 2 ? cells[cells.length - 3].text : '';
    final seeds = cells.length > 1 ? parseIntLoose(cells[cells.length - 2].text) : 0;
    final leeches = cells.isNotEmpty ? parseIntLoose(cells.last.text) : 0;

    final inlineMagnet = row.querySelector('a[href^="magnet:"]')?.attributes['href'];

    results.add(
      SearchResult(
        id: '${sourceId}_${title.hashCode}',
        title: title,
        sourceId: sourceId,
        sourceName: sourceName,
        sizeBytes: parseSizeToBytes(sizeText),
        seeders: seeds,
        leechers: leeches,
        magnetUri: inlineMagnet,
        detailUrl: inlineMagnet == null ? detailUrl : null,
      ),
    );
  }
  return results;
}

List<SearchResult> parse1337xTable(
  String html, {
  required String sourceId,
  required String sourceName,
  required String baseUrl,
}) {
  final document = html_parser.parse(html);
  final rows = document.querySelectorAll('table.table-list tbody tr');
  final results = <SearchResult>[];

  for (final row in rows) {
    final link = row.querySelector('td.name a[href*="/torrent/"]') ??
        row.querySelector('a[href*="/torrent/"]');
    if (link == null) continue;

    final title = link.text.trim();
    if (title.isEmpty) continue;

    final href = link.attributes['href'] ?? '';
    final detailUrl = href.startsWith('http') ? href : '$baseUrl$href';

    final seedsCell = row.querySelector('td.seeds');
    final leechesCell = row.querySelector('td.leeches');
    final sizeCell = row.querySelector('td.size');

    results.add(
      SearchResult(
        id: '${sourceId}_${title.hashCode}',
        title: title,
        sourceId: sourceId,
        sourceName: sourceName,
        sizeBytes: parseSizeToBytes(sizeCell?.text ?? ''),
        seeders: parseIntLoose(seedsCell?.text),
        leechers: parseIntLoose(leechesCell?.text),
        detailUrl: detailUrl,
      ),
    );
  }
  return results;
}

List<SearchResult> parseTorrentGalaxyTable(
  String html, {
  required String sourceId,
  required String sourceName,
  required String baseUrl,
}) {
  final document = html_parser.parse(html);
  final results = <SearchResult>[];

  for (final row in document.querySelectorAll('div.tgxtable div.tgxtablecell')) {
    final link = row.querySelector('a[href*="torrent"]');
    if (link == null) continue;
    final title = link.text.trim();
    if (title.isEmpty) continue;

    final href = link.attributes['href'] ?? '';
    final detailUrl = href.startsWith('http') ? href : '$baseUrl/$href'.replaceAll('//', '/').replaceFirst(':/', '://');
    final magnet = row.querySelector('a[href^="magnet:"]')?.attributes['href'];

    final meta = row.text;
    final seedMatch = RegExp(r'(\d+)\s*seed', caseSensitive: false).firstMatch(meta);
    final leechMatch = RegExp(r'(\d+)\s*leech', caseSensitive: false).firstMatch(meta);
    final sizeMatch = RegExp(r'([\d.]+\s*[GMTK]B)', caseSensitive: false).firstMatch(meta);

    results.add(
      SearchResult(
        id: '${sourceId}_${title.hashCode}',
        title: title,
        sourceId: sourceId,
        sourceName: sourceName,
        sizeBytes: parseSizeToBytes(sizeMatch?.group(1) ?? ''),
        seeders: parseIntLoose(seedMatch?.group(1)),
        leechers: parseIntLoose(leechMatch?.group(1)),
        magnetUri: magnet,
        detailUrl: magnet == null ? detailUrl : null,
      ),
    );
  }

  if (results.isNotEmpty) return results;

  for (final row in document.querySelectorAll('table tr')) {
    final magnet = row.querySelector('a[href^="magnet:"]')?.attributes['href'];
    final link = row.querySelector('a[href*="torrent"]');
    if (link == null) continue;
    final title = link.text.trim();
    if (title.isEmpty) continue;
    final href = link.attributes['href'] ?? '';
    final detailUrl = href.startsWith('http') ? href : '$baseUrl$href';
    results.add(
      SearchResult(
        id: '${sourceId}_${title.hashCode}',
        title: title,
        sourceId: sourceId,
        sourceName: sourceName,
        sizeBytes: 0,
        seeders: 0,
        leechers: 0,
        magnetUri: magnet,
        detailUrl: magnet == null ? detailUrl : null,
      ),
    );
  }
  return results;
}

List<SearchResult> filterMusicResults(List<SearchResult> results) {
  return results.where((r) => looksLikeMusicQuery(r.title)).toList();
}
