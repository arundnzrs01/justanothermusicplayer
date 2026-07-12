import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadDirectoryService.canWriteTo', () {
    late DownloadDirectoryService service;
    late Directory tempDir;

    setUp(() async {
      service = DownloadDirectoryService();
      tempDir = await Directory.systemTemp.createTemp('jamp_write_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns true when write and read succeed', () async {
      final testFile = File('${tempDir.path}/.jamp_write_test');
      await testFile.writeAsString('ok');

      expect(await service.canWriteTo(tempDir.path), isTrue);

      if (await testFile.exists()) {
        await testFile.delete();
      }
    });
  });
}
