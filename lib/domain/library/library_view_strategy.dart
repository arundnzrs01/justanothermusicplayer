import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/features/library/library_screen.dart';

/// Strategy for grouping library content by view mode.
abstract class LibraryViewStrategy {
  String get label;
  List<String> groupKeys(List<Track> tracks);
  LibraryFilter filterForSelection(String key, LibraryFilter current);
}

class SongsViewStrategy implements LibraryViewStrategy {
  @override
  String get label => 'Songs';

  @override
  List<String> groupKeys(List<Track> tracks) => [];

  @override
  LibraryFilter filterForSelection(String key, LibraryFilter current) => current;
}

class ArtistsViewStrategy implements LibraryViewStrategy {
  @override
  String get label => 'Artists';

  @override
  List<String> groupKeys(List<Track> tracks) =>
      tracks.map((t) => t.artist).toSet().toList()..sort();

  @override
  LibraryFilter filterForSelection(String key, LibraryFilter current) =>
      current.copyWith(artist: key);
}

class AlbumsViewStrategy implements LibraryViewStrategy {
  @override
  String get label => 'Albums';

  @override
  List<String> groupKeys(List<Track> tracks) =>
      tracks.map((t) => t.album).toSet().toList()..sort();

  @override
  LibraryFilter filterForSelection(String key, LibraryFilter current) =>
      current.copyWith(album: key);
}

class GenresViewStrategy implements LibraryViewStrategy {
  @override
  String get label => 'Genres';

  @override
  List<String> groupKeys(List<Track> tracks) =>
      tracks.map((t) => t.genre ?? 'Unknown').toSet().toList()..sort();

  @override
  LibraryFilter filterForSelection(String key, LibraryFilter current) =>
      current.copyWith(genre: key);
}

class YearsViewStrategy implements LibraryViewStrategy {
  @override
  String get label => 'Years';

  @override
  List<String> groupKeys(List<Track> tracks) =>
      tracks
          .where((t) => t.year != null)
          .map((t) => t.year.toString())
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  @override
  LibraryFilter filterForSelection(String key, LibraryFilter current) =>
      current.copyWith(year: int.parse(key));
}

class LibraryViewStrategyFactory {
  const LibraryViewStrategyFactory();

  LibraryViewStrategy create(LibraryView view) => switch (view) {
        LibraryView.songs => SongsViewStrategy(),
        LibraryView.artists => ArtistsViewStrategy(),
        LibraryView.albums => AlbumsViewStrategy(),
        LibraryView.genres => GenresViewStrategy(),
        LibraryView.years => YearsViewStrategy(),
      };
}
