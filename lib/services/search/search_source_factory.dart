import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/services/search/source_adapter.dart';
import 'package:torrent_music/services/search/sources/jackett_adapter.dart';
import 'package:torrent_music/services/search/sources/lime_torrents_adapter.dart';
import 'package:torrent_music/services/search/sources/torrent_galaxy_adapter.dart';

/// Factory for constructing search source adapters (Factory pattern).
class SearchSourceFactory {
  const SearchSourceFactory();

  List<SourceAdapter> createSources(AppSettings settings) {
    final sources = <SourceAdapter>[
      TorrentGalaxyAdapter(),
      LimeTorrentsAdapter(),
    ];
    if (settings.indexer.enabled && settings.indexer.isConfigured) {
      sources.insert(0, JackettAdapter(settings.indexer));
    }
    return sources;
  }
}
