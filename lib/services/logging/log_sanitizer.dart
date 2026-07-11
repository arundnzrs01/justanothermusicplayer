import 'package:torrent_music/services/p2p/magnet_link.dart';

/// Returns a privacy-safe summary of pasted magnet/hash input for audit logs.
///
/// Never includes the full URI, full infohash, or tracker URLs.
String sanitizeMagnetPaste(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'type=paste len=0 parse=empty';

  final parsed = MagnetLink.parse(trimmed);
  if (parsed == null) {
    return 'type=paste len=${trimmed.length} parse=failed';
  }

  final hashPrefix = parsed.infoHashHex.length >= 8
      ? parsed.infoHashHex.substring(0, 8)
      : parsed.infoHashHex;
  final buffer = StringBuffer(
    'type=paste len=${trimmed.length} hash=$hashPrefix… trackers=${parsed.trackers.length}',
  );
  final dn = parsed.displayName?.trim();
  if (dn != null && dn.isNotEmpty) {
    buffer.write(' dn="${_escapeQuotes(dn)}"');
  }
  return buffer.toString();
}

String _escapeQuotes(String value) => value.replaceAll('"', '\\"');
