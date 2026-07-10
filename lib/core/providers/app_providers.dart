import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/data/db/app_database.dart' hide Track;
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/data/repositories/library_repository.dart';
import 'package:torrent_music/services/library_scanner.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(databaseProvider));
});

final libraryScannerProvider = Provider<LibraryScanner>((ref) {
  return LibraryScanner(ref.watch(libraryRepositoryProvider));
});

final tracksProvider = FutureProvider<List<Track>>((ref) async {
  return ref.watch(libraryRepositoryProvider).getAllTracks();
});

final artistsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(libraryRepositoryProvider).getArtists();
});

final albumsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(libraryRepositoryProvider).getAlbums();
});

final yearsProvider = FutureProvider<List<int>>((ref) async {
  return ref.watch(libraryRepositoryProvider).getYears();
});

final genresProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(libraryRepositoryProvider).getGenres();
});
