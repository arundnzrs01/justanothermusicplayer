String? buildMagnetFromHash(String? hash, String title) {
  if (hash == null || hash.isEmpty) return null;
  final normalized = hash.toLowerCase().replaceAll('-', '');
  if (normalized.length != 40) return null;
  return 'magnet:?xt=urn:btih:$normalized&dn=${Uri.encodeComponent(title)}';
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
