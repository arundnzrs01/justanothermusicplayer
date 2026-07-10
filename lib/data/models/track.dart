class Track {
  const Track({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.genre,
    this.year,
    this.durationMs = 0,
    this.bitrate,
    this.format,
    this.trackNumber,
    this.discNumber,
    this.albumArtPath,
    this.playCount = 0,
    this.lastPlayed,
    this.dateAdded,
    this.isFavorite = false,
    this.fileHash,
  });

  final int id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String? genre;
  final int? year;
  final int durationMs;
  final int? bitrate;
  final String? format;
  final int? trackNumber;
  final int? discNumber;
  final String? albumArtPath;
  final int playCount;
  final DateTime? lastPlayed;
  final DateTime? dateAdded;
  final bool isFavorite;
  final String? fileHash;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? year,
    int? durationMs,
    int? bitrate,
    String? format,
    int? trackNumber,
    int? discNumber,
    String? albumArtPath,
    int? playCount,
    DateTime? lastPlayed,
    DateTime? dateAdded,
    bool? isFavorite,
    String? fileHash,
  }) {
    return Track(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      durationMs: durationMs ?? this.durationMs,
      bitrate: bitrate ?? this.bitrate,
      format: format ?? this.format,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      fileHash: fileHash ?? this.fileHash,
    );
  }
}
