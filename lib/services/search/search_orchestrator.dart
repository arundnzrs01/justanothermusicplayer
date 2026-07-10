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

  Future<List<SearchResult>> search(String query) async {
    final futures = _sources.map((s) => s.search(query));
    final results = await Future.wait(futures);
    final merged = results.expand((r) => r).toList()
      ..sort((a, b) => b.seeders.compareTo(a.seeders));
    return merged;
  }
}
