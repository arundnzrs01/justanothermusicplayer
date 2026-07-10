import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/search/search_source_factory.dart';
import 'package:torrent_music/services/search/source_adapter.dart';

final searchSourceFactoryProvider = Provider<SearchSourceFactory>((ref) {
  return const SearchSourceFactory();
});

final searchOrchestratorProvider = Provider<SearchOrchestrator>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final factory = ref.watch(searchSourceFactoryProvider);
  return SearchOrchestrator(factory.createSources(settings));
});

class SearchOrchestrator {
  SearchOrchestrator(this._sources);

  final List<SourceAdapter> _sources;
  static const _perSourceTimeout = Duration(seconds: 8);
  static const _overallTimeout = Duration(seconds: 12);

  Future<List<SearchResult>> search(String query) async {
    final merged = <SearchResult>[];
    var pending = _sources.length;
    final completer = Completer<List<SearchResult>>();
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      merged.sort((a, b) => b.seeders.compareTo(a.seeders));
      if (!completer.isCompleted) {
        completer.complete(List.unmodifiable(merged));
      }
    }

    final timer = Timer(_overallTimeout, finish);

    for (final source in _sources) {
      unawaited(_searchSource(source, query).then((results) {
        merged.addAll(results);
        pending--;
        if (pending == 0) finish();
      }));
    }

    final results = await completer.future;
    timer.cancel();
    return results;
  }

  Future<List<SearchResult>> _searchSource(
    SourceAdapter source,
    String query,
  ) async {
    try {
      return await source
          .search(query)
          .timeout(_perSourceTimeout, onTimeout: () => <SearchResult>[]);
    } catch (e, st) {
      debugPrint('${source.displayName} search error: $e\n$st');
      return [];
    }
  }
}
