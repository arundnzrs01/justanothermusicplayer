import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:torrent_music/data/models/search_result.dart';

/// Shared HTTP client for indexer HTML scraping.
class ScrapeClient {
  ScrapeClient() : _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ));

  final Dio _dio;

  Future<String> fetch(String url) async {
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }
}

int parseSizeToBytes(String raw) {
  final text = raw.trim().toUpperCase();
  final match = RegExp(r'([\d.]+)\s*(GB|MB|KB|B)').firstMatch(text);
  if (match == null) return 0;
  final value = double.tryParse(match.group(1)!) ?? 0;
  return switch (match.group(2)) {
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
    final cells = row.querySelectorAll('td');
    if (cells.length < 4) continue;

    final sizeText = cells.length > 2 ? cells[cells.length - 3].text : '';
    final seeds = cells.length > 1 ? parseIntLoose(cells[cells.length - 2].text) : 0;
    final leeches = cells.length > 0 ? parseIntLoose(cells.last.text) : 0;

    results.add(
      SearchResult(
        id: '${sourceId}_${title.hashCode}',
        title: title,
        sourceId: sourceId,
        sourceName: sourceName,
        sizeBytes: parseSizeToBytes(sizeText),
        seeders: seeds,
        leechers: leeches,
        magnetUri: href.startsWith('http') ? null : '$baseUrl$href',
      ),
    );
  }
  return results;
}
