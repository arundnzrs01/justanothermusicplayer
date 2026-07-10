import 'package:torrent_music/services/search/magnet_utils.dart';

class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.sourceName,
    required this.sizeBytes,
    required this.seeders,
    required this.leechers,
    this.quality,
    this.date,
    this.magnetUri,
    this.infoHash,
    this.detailUrl,
  });

  final String id;
  final String title;
  final String sourceId;
  final String sourceName;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final String? quality;
  final DateTime? date;
  final String? magnetUri;
  final String? infoHash;
  final String? detailUrl;

  String? get effectiveMagnet =>
      magnetUri ?? buildMagnetFromHash(infoHash, title);

  bool get canDownload =>
      effectiveMagnet != null || detailUrl != null || infoHash != null;
}
