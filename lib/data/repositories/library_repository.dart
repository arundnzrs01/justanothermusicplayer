import 'package:drift/drift.dart' as drift;
import 'package:torrent_music/data/db/app_database.dart' as db;
import 'package:torrent_music/data/models/track.dart';

class LibraryRepository {
  LibraryRepository(this._database);

  final db.AppDatabase _database;

  Future<List<Track>> getAllTracks() async {
    final rows = await _database.getAllTracks();
    return rows.map(_mapTrack).toList();
  }

  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return getAllTracks();
    final rows = await _database.searchTracks(query);
    return rows.map(_mapTrack).toList();
  }

  Future<List<Track>> filter({
    String? artist,
    String? album,
    int? year,
    String? genre,
    String? format,
  }) async {
    final rows = await _database.filterTracks(
      artist: artist,
      album: album,
      year: year,
      genre: genre,
      format: format,
    );
    return rows.map(_mapTrack).toList();
  }

  Future<List<String>> getArtists() => _database.distinctArtists();
  Future<List<String>> getAlbums() => _database.distinctAlbums();
  Future<List<int>> getYears() => _database.distinctYears();
  Future<List<String>> getGenres() => _database.distinctGenres();

  Future<void> upsertTrack(Track track) {
    return _database.upsertTrack(
      db.TracksCompanion.insert(
        path: track.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        genre: drift.Value(track.genre),
        year: drift.Value(track.year),
        durationMs: drift.Value(track.durationMs),
        bitrate: drift.Value(track.bitrate),
        format: drift.Value(track.format),
        trackNumber: drift.Value(track.trackNumber),
        discNumber: drift.Value(track.discNumber),
        albumArtPath: drift.Value(track.albumArtPath),
        playCount: drift.Value(track.playCount),
        lastPlayed: drift.Value(track.lastPlayed),
        dateAdded: drift.Value(track.dateAdded ?? DateTime.now()),
        isFavorite: drift.Value(track.isFavorite),
        fileHash: drift.Value(track.fileHash),
      ),
    );
  }

  Future<void> toggleFavorite(int trackId, bool favorite) async {
    final rows = await _database.getAllTracks();
    final row = rows.firstWhere((t) => t.id == trackId);
    await upsertTrack(_mapTrack(row).copyWith(isFavorite: favorite));
  }

  Track _mapTrack(db.Track row) {
    return Track(
      id: row.id,
      path: row.path,
      title: row.title,
      artist: row.artist,
      album: row.album,
      genre: row.genre,
      year: row.year,
      durationMs: row.durationMs,
      bitrate: row.bitrate,
      format: row.format,
      trackNumber: row.trackNumber,
      discNumber: row.discNumber,
      albumArtPath: row.albumArtPath,
      playCount: row.playCount,
      lastPlayed: row.lastPlayed,
      dateAdded: row.dateAdded,
      isFavorite: row.isFavorite,
      fileHash: row.fileHash,
    );
  }
}
