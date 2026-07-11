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
  static String prepareMagnet(
    String magnet, {
    required List<String> globalTrackers,
    List<String> perDownloadTrackers = const [],
  }) {
    final parsed = MagnetLink.parse(magnet);
    if (parsed == null) return magnet.trim();

    final embedded = parsed.trackers.length;
    final extras = <String>[];

    // No embedded trackers → add fallbacks + global list (DHT alone can be slow).
    if (embedded == 0) {
      extras.addAll(kFallbackAnnounceUrls);
    }

    extras.addAll(globalTrackers);
    extras.addAll(perDownloadTrackers);

    // Magnets with trackers already: add fewer extras (libtorrent also injects).
    final maxTotal = embedded >= 2 ? embedded + 3 : 10;

    return parsed.toUri(extraTrackers: extras, maxTrackers: maxTotal);
  }
}
