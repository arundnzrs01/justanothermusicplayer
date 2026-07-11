import 'package:torrent_music/services/p2p/magnet_link.dart';

String? buildMagnetFromHash(String? hash, String title) {
  if (hash == null || hash.isEmpty) return null;
  final normalized = hash.toLowerCase().replaceAll('-', '').trim();

  if (RegExp(r'^[0-9a-f]{40}$').hasMatch(normalized)) {
    return MagnetLink(infoHashHex: normalized, displayName: title).toUri();
  }

  // apibay / some APIs return 32-char hex (truncated v1 hash).
  if (RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized)) {
    return MagnetLink(
      infoHashHex: normalized,
      displayName: title,
    ).toUri();
  }

  if (RegExp(r'^[a-z2-7]{32}$').hasMatch(normalized)) {
    final parsed = MagnetLink.parse('magnet:?xt=urn:btih:$normalized');
    if (parsed == null) return null;
    return MagnetLink(
      infoHashHex: parsed.infoHashHex,
      displayName: title,
    ).toUri();
  }

  return null;
}

String? extractMagnetFromHtml(String html) {
  final match = RegExp(r'magnet:\?[^\s"<>]+', caseSensitive: false).firstMatch(html);
  if (match == null) return null;
  return sanitizeMagnetInput(match.group(0)!);
}

bool looksLikeMusicQuery(String title) {
  final lower = title.toLowerCase();
  const audioExt = ['.mp3', '.flac', '.m4a', '.wav', '.aac', '.ogg', '.opus'];
  if (audioExt.any(lower.contains)) return true;
  const keywords = [
    'flac', 'mp3', '320', 'album', 'discography', 'ost', 'soundtrack',
    'single', 'ep ', ' vinyl', 'lossless', 'aac', 'm4a',
  ];
  return keywords.any(lower.contains);
}
