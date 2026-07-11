/// Parsed magnet URI per BitTorrent spec (infohash + optional trackers + display name).
///
/// See: https://stackoverflow.com/questions/3844502/how-do-bittorrent-magnet-links-work
/// Magnets identify content by infohash; peers come from embedded `tr=` trackers,
/// DHT (BEP-5), and PEX once connected to the swarm.
class MagnetLink {
  MagnetLink({
    required this.infoHashHex,
    this.displayName,
    this.trackers = const [],
    this.raw = '',
  });

  /// 40-char lowercase SHA-1 infohash (hex).
  final String infoHashHex;
  final String? displayName;
  final List<String> trackers;
  final String raw;

  bool get hasTrackers => trackers.isNotEmpty;

  static MagnetLink? parse(String link) {
    final trimmed = link.trim();
    if (!trimmed.startsWith('magnet:?')) return null;

    final hash = _extractInfoHashHex(trimmed);
    if (hash == null) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final trackers = <String>[];
    for (final tr in uri.queryParametersAll['tr'] ?? const []) {
      final t = tr.trim();
      if (t.isNotEmpty && !trackers.contains(t)) trackers.add(t);
    }

    final dn = uri.queryParameters['dn'];

    return MagnetLink(
      infoHashHex: hash,
      displayName: dn != null ? Uri.decodeComponent(dn) : null,
      trackers: trackers,
      raw: trimmed,
    );
  }

  /// Canonical magnet with infohash + display name + trackers (for libtorrent).
  String toUri({
    List<String> extraTrackers = const [],
    int maxTrackers = 8,
  }) {
    final buffer = StringBuffer('magnet:?xt=urn:btih:$infoHashHex');
    if (displayName != null && displayName!.isNotEmpty) {
      buffer.write('&dn=${Uri.encodeComponent(displayName!)}');
    }

    final seen = <String>{};
    var added = 0;
    for (final tr in [...trackers, ...extraTrackers]) {
      if (added >= maxTrackers) break;
      final t = tr.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      buffer.write('&tr=${Uri.encodeComponent(t)}');
      added++;
    }
    return buffer.toString();
  }

  static String? _extractInfoHashHex(String magnet) {
    final match = RegExp(
      r'xt=urn:btih:([0-9a-zA-Z]+)',
      caseSensitive: false,
    ).firstMatch(magnet);
    if (match == null) return null;

    final token = match.group(1)!.toLowerCase();

    if (RegExp(r'^[0-9a-f]{40}$').hasMatch(token)) {
      return token;
    }

    if (RegExp(r'^[0-9a-f]{32}$').hasMatch(token)) {
      return token.padRight(40, '0');
    }

    if (RegExp(r'^[a-z2-7]{32}$').hasMatch(token)) {
      return _base32ToHex(token);
    }

    return null;
  }

  static String _base32ToHex(String base32) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
    var buffer = 0;
    var bitsLeft = 0;
    final bytes = <int>[];

    for (final code in base32.toLowerCase().codeUnits) {
      final char = String.fromCharCode(code);
      final idx = alphabet.indexOf(char);
      if (idx < 0) continue;
      buffer = (buffer << 5) | idx;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

String normalizeMagnet(String link) {
  final parsed = MagnetLink.parse(link);
  if (parsed == null) return link.trim();
  return parsed.toUri(maxTrackers: parsed.trackers.length);
}

bool isValidMagnet(String link) => MagnetLink.parse(link) != null;

String? extractInfoHashHex(String link) => MagnetLink.parse(link)?.infoHashHex;

List<String> extractMagnetTrackers(String link) =>
    MagnetLink.parse(link)?.trackers ?? const [];

/// Inject extra tracker announce URLs (only when magnet lacks them).
String injectTrackersIntoMagnet(
  String magnet,
  List<String> trackers, {
  int maxTrackers = 8,
}) {
  final parsed = MagnetLink.parse(magnet);
  if (parsed == null || trackers.isEmpty) return magnet;

  return parsed.toUri(extraTrackers: trackers, maxTrackers: maxTrackers);
}

/// Parsed magnet URI