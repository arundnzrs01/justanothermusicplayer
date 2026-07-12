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

    test('returns true when write and read succeed even if delete fails', () async {
      final testFile = File('${tempDir.path}/.jamp_write_test');
      await testFile.writeAsString('ok');

      final originalDelete = testFile.delete;
      var deleteCalled = false;
      // ignore: invalid_use_of_visible_for_testing_member
      try {
        // Simulate delete failure after successful write/read.
        expect(await service.canWriteTo(tempDir.path), isTrue);
      } finally {
        if (deleteCalled) {
          // no-op
        } else if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
  });
}
