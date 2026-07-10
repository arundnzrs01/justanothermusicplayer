import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/magnet_utils.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

/// The Pirate Bay via apibay JSON API.
class TpbAdapter implements SourceAdapter {
  TpbAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const _api = 'https://apibay.org';

  @override
  String get id => 'tpb';

  @override
  String get displayName => 'TPB';

  @override
  Future<List<SearchResult>> search(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final response = await _dio.get<List<dynamic>>(
        '$_api/q.php?q=$encoded&cat=100',
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final rows = response.data ?? [];
      final results = <SearchResult>[];

      for (final raw in rows) {
        if (raw is! Map<String, dynamic>) continue;
        final title = (raw['name'] as String?)?.trim();
        final hash = (raw['info_hash'] as String?)?.trim();
        if (title == null || title.isEmpty || hash == null || hash.isEmpty) continue;
        if (title.toLowerCase() == 'no results returned') continue;

        results.add(
          SearchResult(
            id: 'tpb_${raw['id'] ?? title.hashCode}',
            title: title,
            sourceId: id,
            sourceName: displayName,
            sizeBytes: int.tryParse('${raw['size']}') ?? 0,
            seeders: parseIntLoose('${raw['seeders']}'),
            leechers: parseIntLoose('${raw['leechers']}'),
            infoHash: hash,
            magnetUri: buildMagnetFromHash(hash, title),
          ),
        );
      }

      final music = filterMusicResults(results);
      return (music.isNotEmpty ? music : results).take(25).toList();
    } catch (e, st) {
      debugPrint('TPB search failed: $e\n$st');
      return [];
    }
  }
}
