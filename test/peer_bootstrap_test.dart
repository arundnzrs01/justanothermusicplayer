import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/p2p/peer_bootstrap.dart';

void main() {
  group('PeerBootstrap.collectTrackers', () {
    test('adds fallbacks when magnet has no embedded trackers', () {
      final trackers = PeerBootstrap.collectTrackers(
        embeddedCount: 0,
        globalTrackers: const ['udp://global.example:6969/announce'],
        perDownloadTrackers: const ['udp://per.example:6969/announce'],
      );

      expect(trackers, contains('udp://global.example:6969/announce'));
      expect(trackers, contains('udp://per.example:6969/announce'));
      expect(trackers, contains(kFallbackAnnounceUrls.first));
    });

    test('skips fallbacks when embedded trackers exist', () {
      final trackers = PeerBootstrap.collectTrackers(
        embeddedCount: 2,
        globalTrackers: const ['udp://global.example:6969/announce'],
      );

      expect(trackers, contains('udp://global.example:6969/announce'));
      for (final fallback in kFallbackAnnounceUrls) {
        expect(trackers, isNot(contains(fallback)));
      }
    });

    test('dedupes tracker URLs', () {
      final trackers = PeerBootstrap.collectTrackers(
        embeddedCount: 1,
        globalTrackers: const ['udp://same.example:6969/announce'],
        perDownloadTrackers: const ['udp://same.example:6969/announce'],
      );

      expect(
        trackers.where((t) => t == 'udp://same.example:6969/announce').length,
        1,
      );
    });
  });
}
