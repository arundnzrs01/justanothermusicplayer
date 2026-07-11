import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:torrent_music/data/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks, Downloads, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Track>> getAllTracks() => select(tracks).get();

  Future<List<Track>> searchTracks(String query) {
    final q = '%${query.toLowerCase()}%';
    return (select(tracks)
          ..where((t) =>
              t.title.lower().like(q) |
              t.artist.lower().like(q) |
              t.album.lower().like(q)))
        .get();
  }

  Future<List<Track>> filterTracks({
    String? artist,
    String? album,
    int? year,
    String? genre,
    String? format,
  }) {
    final query = select(tracks);
    if (artist != null && artist.isNotEmpty) {
      query.where((t) => t.artist.equals(artist));
    }
    if (album != null && album.isNotEmpty) {
      query.where((t) => t.album.equals(album));
    }
    if (year != null) {
      query.where((t) => t.year.equals(year));
    }
    if (genre != null && genre.isNotEmpty) {
      query.where((t) => t.genre.equals(genre));
    }
    if (format != null && format.isNotEmpty) {
      query.where((t) => t.format.equals(format));
    }
    return query.get();
  }

  Future<List<String>> distinctArtists() async {
    final rows = await customSelect(
      'SELECT DISTINCT artist FROM tracks ORDER BY artist',
      readsFrom: {tracks},
    ).get();
    return rows.map((r) => r.read<String>('artist')).toList();
  }

  Future<List<String>> distinctAlbums() async {
    final rows = await customSelect(
      'SELECT DISTINCT album FROM tracks ORDER BY album',
      readsFrom: {tracks},
    ).get();
    return rows.map((r) => r.read<String>('album')).toList();
  }

  Future<List<int>> distinctYears() async {
    final rows = await customSelect(
      'SELECT DISTINCT year FROM tracks WHERE year IS NOT NULL ORDER BY year DESC',
      readsFrom: {tracks},
    ).get();
    return rows.map((r) => r.read<int>('year')).toList();
  }

  Future<List<String>> distinctGenres() async {
    final rows = await customSelect(
      'SELECT DISTINCT genre FROM tracks WHERE genre IS NOT NULL ORDER BY genre',
      readsFrom: {tracks},
    ).get();
    return rows.map((r) => r.read<String>('genre')).toList();
  }

  Future<int> upsertTrack(TracksCompanion entry) {
    return into(tracks).insertOnConflictUpdate(entry);
  }

  Future<void> deleteTrackByPath(String path) {
    return (delete(tracks)..where((t) => t.path.equals(path))).go();
  }

  Future<List<Download>> getAllDownloads() => select(downloads).get();

  Future<void> upsertDownload(DownloadsCompanion entry) {
    return into(downloads).insertOnConflictUpdate(entry);
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(key: Value(key), value: Value(value)),
    );
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'torrent_music');
}
