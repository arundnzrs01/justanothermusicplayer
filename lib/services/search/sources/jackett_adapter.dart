import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

/// Jackett / Torznab-compatible API adapter.
class JackettAdapter implements SourceAdapter {
  JackettAdapter(this.config) : _dio = Dio();

  final IndexerConfig config;
  final Dio _dio;

  @override
  String get id => 'jackett_custom';

  @override
  String get displayName => config.displayName;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (!config.enabled || !config.isConfigured) return [];

    try {
      final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v2.0/indexers/all/results').replace(
        queryParameters: {
          'apikey': config.apiKey,
          'Query': query,
        },
      );

      final response = await _dio.get<Map<String, dynamic>>(
        uri.toString(),
        options: Options(
          headers: {'Accept': 'application/json'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final results = response.data?['Results'] as List<dynamic>? ?? [];
      return results.map((raw) => _mapResult(raw as Map<String, dynamic>)).whereType<SearchResult>().toList();
    } catch (e, st) {
      debugPrint('Jackett search failed: $e\n$st');
      return [];
    }
  }

  SearchResult? _mapResult(Map<String, dynamic> json) {
    final title = (json['Title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final magnet = json['MagnetUri'] as String? ?? json['Link'] as String?;
    final infoHash = json['InfoHash'] as String?;
    final size = json['Size'];
    final seeders = json['Seeders'] ?? json['Grabs'];
    final peers = json['Peers'] ?? json['Leechers'];

    return SearchResult(
      id: 'jackett_${title.hashCode}_${json['Guid'] ?? ''}',
      title: title,
      sourceId: id,
      sourceName: displayName,
      sizeBytes: size is int ? size : int.tryParse('$size') ?? 0,
      seeders: seeders is int ? seeders : int.tryParse('$seeders') ?? 0,
      leechers: peers is int ? peers : int.tryParse('$peers') ?? 0,
      quality: json['CategoryDesc'] as String?,
      magnetUri: magnet?.startsWith('magnet:') == true ? magnet : null,
      infoHash: infoHash?.length == 40 ? infoHash : null,
    );
  }
}
