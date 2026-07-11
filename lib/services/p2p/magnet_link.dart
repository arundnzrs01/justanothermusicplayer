/// Parsed magnet URI per BitTorrent spec (infohash + optional trackers + display name).
///
/// See: https://stackoverflow.com/questions/3844502/how-do-bittorrent-magnet-links-work
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
    final sanitized = sanitizeMagnetInput(link);
    if (sanitized.isEmpty) return null;

    // Raw 40-char hex hash pasted without magnet: prefix.
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(sanitized)) {
      return MagnetLink(
        infoHashHex: sanitized.toLowerCase(),
        raw: sanitized,
      );
    }

    if (!sanitized.toLowerCase().startsWith('magnet:')) return null;

    final hash = _extractInfoHashHex(sanitized);
    if (hash == null || hash.length != 40) return null;

    final trackers = _extractTrackers(sanitized);
    final dn = _extractDisplayName(sanitized);

    return MagnetLink(
      infoHashHex: hash,
      displayName: dn,
      trackers: trackers,
      raw: sanitized,
    );
  }

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

  static String sanitizeMagnetInput(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    s = s
        .replaceAll('&amp;', '&')
        .replaceAll('&#38;', '&')
        .replaceAll('&#x26;', '&');

    final embedded = RegExp(
      r'magnet:\?[^\s"<>]+',
      caseSensitive: false,
    ).firstMatch(s);
    if (embedded != null) {
      s = embedded.group(0)!;
    }

    if (s.toLowerCase().startsWith('magnet:')) {
      s = s.replaceFirst(RegExp(r'^magnet:\s*', caseSensitive: false), 'magnet:');
      if (!s.startsWith('magnet:?')) {
        final rest = s.substring('magnet:'.length);
        s = rest.startsWith('?') ? 'magnet:$rest' : 'magnet:?${rest.startsWith('xt=') ? rest : rest}';
      }
    }

    return s.trim();
  }

  static String? _extractInfoHashHex(String magnet) {
    final match = RegExp(
      r'(?:\?|&)?xt=urn:btih:([0-9a-zA-Z]+)',
      caseSensitive: false,
    ).firstMatch(magnet);
    if (match == null) return null;

    var token = match.group(1)!;
    final amp = token.indexOf('&');
    if (amp >= 0) token = token.substring(0, amp);
    token = token.toLowerCase();

    if (RegExp(r'^[0-9a-f]{40}$').hasMatch(token)) {
      return token;
    }

    if (RegExp(r'^[0-9a-f]{32}$').hasMatch(token)) {
      return token.padRight(40, '0');
    }

    if (RegExp(r'^[a-z2-7]{32}$').hasMatch(token)) {
      final hex = _base32ToHex(token);
      return hex.length == 40 ? hex : null;
    }

    return null;
  }

  static List<String> _extractTrackers(String magnet) {
    final trackers = <String>[];
    final matches = RegExp(
      r'(?:\?|&)tr=([^&]+)',
      caseSensitive: false,
    ).allMatches(magnet);

    for (final match in matches) {
      var tr = match.group(1)!;
      try {
        tr = Uri.decodeComponent(tr);
      } catch (_) {}
      tr = tr.trim();
      if (tr.isNotEmpty && !trackers.contains(tr)) {
        trackers.add(tr);
      }
    }
    return trackers;
  }

  static String? _extractDisplayName(String magnet) {
    final match = RegExp(
      r'(?:\?|&)dn=([^&]*)',
      caseSensitive: false,
    ).firstMatch(magnet);
    if (match == null) return null;
    try {
      return Uri.decodeComponent(match.group(1)!);
    } catch (_) {
      return match.group(1);
    }
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

    if (bytes.length != 20) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().padRight(40, '0').substring(0, 40);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

String sanitizeMagnetInput(String link) => MagnetLink.sanitizeMagnetInput(link);

String normalizeMagnet(String link) {
  final parsed = MagnetLink.parse(link);
  if (parsed == null) return sanitizeMagnetInput(link);
  return parsed.toUri(maxTrackers: parsed.trackers.length.clamp(0, 20));
}

bool isValidMagnet(String link) => MagnetLink.parse(link) != null;

String? extractInfoHashHex(String link) => MagnetLink.parse(link)?.infoHashHex;

List<String> extractMagnetTrackers(String link) =>
    MagnetLink.parse(link)?.trackers ?? const [];

String injectTrackersIntoMagnet(
  String magnet,
  List<String> trackers, {
  int maxTrackers = 8,
}) {
  final parsed = MagnetLink.parse(magnet);
  if (parsed == null || trackers.isEmpty) return magnet;
  return parsed.toUri(extraTrackers: trackers, maxTrackers: maxTrackers);
}
