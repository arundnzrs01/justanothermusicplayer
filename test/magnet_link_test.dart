import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/p2p/magnet_link.dart';
import 'package:torrent_music/services/search/magnet_utils.dart';

void main() {
  test('parses standard magnet', () {
    final p = MagnetLink.parse(
      'magnet:?xt=urn:btih:0102030405060708090a0b0c0d0e0f1011121314&dn=test',
    );
    expect(p, isNotNull);
    expect(p!.infoHashHex.length, 40);
  });

  test('parses magnet without question mark', () {
    final p = MagnetLink.parse(
      'magnet:xt=urn:btih:0102030405060708090a0b0c0d0e0f1011121314',
    );
    expect(p, isNotNull);
  });

  test('parses html-encoded trackers', () {
    final p = MagnetLink.parse(
      'magnet:?xt=urn:btih:0102030405060708090a0b0c0d0e0f1011121314&amp;tr=http://tracker.example/announce',
    );
    expect(p, isNotNull);
    expect(p!.trackers.length, 1);
  });

  test('parses raw 40-char hash', () {
    final p = MagnetLink.parse('0102030405060708090a0b0c0d0e0f1011121314');
    expect(p, isNotNull);
  });

  test('buildMagnetFromHash for 40 hex', () {
    final m = buildMagnetFromHash(
      '0102030405060708090a0b0c0d0e0f1011121314',
      'Album',
    );
    expect(m, isNotNull);
    expect(MagnetLink.parse(m!), isNotNull);
  });
}
