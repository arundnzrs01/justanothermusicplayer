import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/services/p2p/download_persistence.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late DownloadPersistence persistence;

  const hash = '0102030405060708090a0b0c0d0e0f1011121314';
  const magnet =
      'magnet:?xt=urn:btih:$hash&dn=Test%20Album&tr=http://tracker.example/announce';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jamp_persist_test');
    database = AppDatabase(executor: NativeDatabase.memory());
    persistence = DownloadPersistence(
      database: database,
      downloadDir: tempDir.path,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resume file round-trip', () async {
    final data = Uint8List.fromList([10, 20, 30, 40]);

    await persistence.writeResume(magnet, data);

    final path = persistence.resumePathFor(magnet);
    expect(path, endsWith('$hash.resume'));
    expect(File(path!).existsSync(), isTrue);

    final loaded = await persistence.readResume(magnet);
    expect(loaded, data);
  });

  test('deleteResume removes file', () async {
    await persistence.writeResume(magnet, Uint8List.fromList([1]));
    await persistence.deleteResume(magnet);
    expect(await persistence.readResume(magnet), isNull);
  });
}
