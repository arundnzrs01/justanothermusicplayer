import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/logging/log_sanitizer.dart';

void main() {
  const hash = '0102030405060708090a0b0c0d0e0f1011121314';
  const magnet =
      'magnet:?xt=urn:btih:$hash&dn=Test%20Album&tr=http://tracker.example/announce&tr=http://tracker2.example/announce';

  test('sanitized magnet paste omits full URI and trackers', () {
    final sanitized = sanitizeMagnetPaste(magnet);

    expect(sanitized, contains('type=paste'));
    expect(sanitized, contains('len=${magnet.length}'));
    expect(sanitized, contains('hash=01020304…'));
    expect(sanitized, contains('trackers=2'));
    expect(sanitized, contains('dn="Test Album"'));

    expect(sanitized, isNot(contains('magnet:')));
    expect(sanitized, isNot(contains(hash)));
    expect(sanitized, isNot(contains('tracker.example')));
  });

  test('sanitized raw hash paste truncates infohash', () {
    final sanitized = sanitizeMagnetPaste(hash);

    expect(sanitized, contains('hash=01020304…'));
    expect(sanitized, isNot(contains(hash)));
  });

  test('invalid paste logs length and parse failure only', () {
    final sanitized = sanitizeMagnetPaste('not a magnet at all');

    expect(sanitized, 'type=paste len=19 parse=failed');
    expect(sanitized, isNot(contains('magnet')));
  });

  test('empty paste is handled', () {
    expect(sanitizeMagnetPaste(''), 'type=paste len=0 parse=empty');
    expect(sanitizeMagnetPaste('   '), 'type=paste len=0 parse=empty');
  });
}
