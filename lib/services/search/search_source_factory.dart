import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/services/search/source_adapter.dart';
import 'package:torrent_music/services/search/sources/jackett_adapter.dart';
import 'package:torrent_music/services/search/sources/lime_torrents_adapter.dart';
import 'package:torrent_music/services/search/sources/torlock_adapter.dart';
import 'package:torrent_music/services/search/sources/torrent_galaxy_adapter.dart';
import 'package:torrent_music/services/search/sources/tpb_adapter.dart';
import 'package:torrent_music/services/search/sources/x1337_adapter.dart';

/// Factory for constructing search source adapters (Factory pattern).
class SearchSourceFactory {
  const SearchSourceFactory();

  List<SourceAdapter> createSources(AppSettings settings) {
    final sources = <SourceAdapter>[
      TpbAdapter(),
      X1337Adapter(),
      TorrentGalaxyAdapter(),
      LimeTorrentsAdapter(),
      TorlockAdapter(),
    ];
    if (settings.indexer.enabled && settings.indexer.isConfigured) {
      sources.insert(0, JackettAdapter(settings.indexer));
    }
    return sources;
  }
}
