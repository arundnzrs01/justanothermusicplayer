import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';

/// libtorrent session settings aligned with BitTorrent bootstrapping:
/// trackers + DHT for peer discovery, UPnP for inbound connections.
class TorrentSessionConfig {
  static BtConfig forSettings(AppSettings settings) {
    final base = const BtConfig(
      disableDht: false,
      disableUpnp: false,
      disableUpload: false,
      disableTcp: false,
      disableUtp: false,
      connectionsLimit: 80,
      responsiveMode: true,
    );

    return base.copyWith(
      downloadRateLimit: settings.downloadLimitKbps,
      uploadRateLimit: settings.uploadLimitKbps,
    );
  }
}

/// User-facing labels for libtorrent states (metadata → pieces → verify).
String torrentPhaseLabel(TorrentState state) {
  switch (state) {
    case TorrentState.downloadingMetadata:
      return 'Fetching metadata from peers';
    case TorrentState.checkingFiles:
    case TorrentState.checkingResume:
      return 'Checking files';
    case TorrentState.allocating:
      return 'Preparing storage';
    case TorrentState.downloading:
      return 'Downloading pieces';
    case TorrentState.finished:
    case TorrentState.seeding:
      return 'Complete';
    case TorrentState.error:
      return 'Error';
    case TorrentState.unknown:
      return 'Connecting';
  }
}
