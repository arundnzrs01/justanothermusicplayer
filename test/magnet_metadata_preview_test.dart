import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/p2p/magnet_metadata_preview.dart';

void main() {
  group('MagnetMetadataPreview.canStartDownload', () {
    test('enabled when metadata is ready', () {
      const preview = MagnetMetadataPreview(
        prefetchId: 'id',
        hasMetadata: true,
      );
      expect(preview.canStartDownload, isTrue);
    });

    test('enabled when finished but progress is partial', () {
      const preview = MagnetMetadataPreview(
        prefetchId: 'id',
        hasMetadata: false,
        isCompleted: true,
        progress: 0.5,
      );
      expect(preview.canStartDownload, isTrue);
    });

    test('disabled while metadata is still loading', () {
      const preview = MagnetMetadataPreview(
        prefetchId: 'id',
        isLoading: true,
      );
      expect(preview.canStartDownload, isFalse);
    });

    test('disabled when already complete', () {
      const preview = MagnetMetadataPreview(
        prefetchId: 'id',
        hasMetadata: true,
        isCompleted: true,
        progress: 1,
      );
      expect(preview.canStartDownload, isFalse);
    });
  });
}
