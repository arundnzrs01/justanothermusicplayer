import 'package:torrent_music/services/p2p/magnet_link.dart';

/// Fallback announce URLs when a magnet has no embedded `tr=` trackers.
/// DHT (BEP-5) can still find peers, but trackers bootstrap faster.
const kFallbackAnnounceUrls = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.stealth.si:80/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://exodus.desync.com:6969/announce',
  'udp://tracker.tiny-vps.com:6969/announce',
];

/// Peer discovery bootstrap — trackers (phonebook) + DHT (distributed lookup).
///
/// Per Stack Overflow / BEP-5: a magnet with only an infohash can work via DHT,
/// but embedded `tr=` URLs and fallback trackers improve first-peer discovery.
class PeerBootstrap {
  /// Collect tracker URLs for post-metadata injection (not embedded in magnet URI).
  static List<String> collectTrackers({
    required int embeddedCount,
    required List<String> globalTrackers,
    List<String> perDownloadTrackers = const [],
  }) {
    final extras = <String>[];
    if (embeddedCount == 0) {
      extras.addAll(kFallbackAnnounceUrls);
    }
    extras.addAll(globalTrackers);
    extras.addAll(perDownloadTrackers);

    final seen = <String>{};
    final out = <String>[];
    for (final url in extras) {
      final trimmed = url.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      out.add(trimmed);
    }
    return out;
  }

  static String prepareMagnet(
    String magnet, {
    required List<String> globalTrackers,
    List<String> perDownloadTrackers = const [],
  }) {
    final parsed = MagnetLink.parse(magnet);
    if (parsed == null) return magnet.trim();

    final embedded = parsed.trackers.length;
    final extras = collectTrackers(
      embeddedCount: embedded,
      globalTrackers: globalTrackers,
      perDownloadTrackers: perDownloadTrackers,
    );

    // Magnets with trackers already: add fewer extras (libtorrent also injects).
    final maxTotal = embedded >= 2 ? embedded + 3 : 10;

    return parsed.toUri(extraTrackers: extras, maxTrackers: maxTotal);
  }
}
