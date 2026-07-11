import 'package:torrent_music/services/p2p/magnet_link.dart';

String? buildMagnetFromHash(String? hash, String title) {
  if (hash == null || hash.isEmpty) return null;
  final normalized = hash.toLowerCase().replaceAll('-', '');

  String? infoHex;
  if (RegExp(r'^[0-9a-f]{40}$').hasMatch(normalized)) {
    infoHex = normalized;
  } else if (RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized)) {
    infoHex = normalized.padRight(40, '0');
  } else if (RegExp(r'^[a-z2-7]{32}$').hasMatch(normalized)) {
    infoHex = MagnetLink.parse('magnet:?xt=urn:btih:$normalized')?.infoHashHex;
  }

  if (infoHex == null) return null;
  return MagnetLink(infoHashHex: infoHex, displayName: title).toUri();
}

String? extractMagnetFromHtml(String html) {
  return RegExp(r'magnet:\?[^\s"<>]+', caseSensitive: false).firstMatch(html)?.group(0);
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
