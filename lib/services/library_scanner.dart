import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/data/repositories/library_repository.dart';

const audioExtensions = {'.mp3', '.flac', '.m4a', '.ogg', '.wav', '.aac', '.opus'};

class LibraryScanner {
  LibraryScanner(this._repository);

  final LibraryRepository _repository;

  Future<int> scanDirectory(String rootPath) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) return 0;

    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!audioExtensions.contains(ext)) continue;

      final fileName = p.basenameWithoutExtension(entity.path);
      final parts = entity.path.split(Platform.pathSeparator);
      String artist = 'Unknown Artist';
      String album = 'Unknown Album';
      if (parts.length >= 3) {
        album = parts[parts.length - 2];
        artist = parts[parts.length - 3];
      }

      await _repository.upsertTrack(
        Track(
          id: 0,
          path: entity.path,
          title: _prettifyTitle(fileName),
          artist: artist,
          album: album,
          format: ext.replaceFirst('.', '').toUpperCase(),
          dateAdded: DateTime.now(),
        ),
      );
      count++;
    }
    return count;
  }

  String _prettifyTitle(String raw) {
    return raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  }
}
