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
}
