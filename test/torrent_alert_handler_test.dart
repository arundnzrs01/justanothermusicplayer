import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:torrent_music/services/p2p/torrent_alert_handler.dart';

void main() {
  test('dispatches alert kinds to callbacks', () {
    int? finishedId;
    int? metadataId;
    int? errorId;
    String? errorMsg;
    int? fileErrorId;
    String? fileErrorMsg;
    int? resumeId;
    Uint8List? resumeBytes;

    final handler = TorrentAlertHandler(
      onFinished: (id) => finishedId = id,
      onError: (id, msg) {
        errorId = id;
        errorMsg = msg;
      },
      onFileError: (id, msg) {
        fileErrorId = id;
        fileErrorMsg = msg;
      },
      onMetadataReceived: (id) => metadataId = id,
      onSaveResumeData: (id, bytes) {
        resumeId = id;
        resumeBytes = bytes;
      },
      takeResumeData: (_) => Uint8List.fromList([1, 2, 3]),
    );

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.finished,
        torrentId: 7,
        message: '',
      ),
    );
    expect(finishedId, 7);

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.metadataReceived,
        torrentId: 3,
        message: '',
      ),
    );
    expect(metadataId, 3);

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.error,
        torrentId: 2,
        message: 'tracker fail',
      ),
    );
    expect(errorId, 2);
    expect(errorMsg, 'tracker fail');

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.fileError,
        torrentId: 4,
        message: 'disk full',
      ),
    );
    expect(fileErrorId, 4);
    expect(fileErrorMsg, 'disk full');

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.saveResumeData,
        torrentId: 9,
        message: '',
      ),
    );
    expect(resumeId, 9);
    expect(resumeBytes, Uint8List.fromList([1, 2, 3]));

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.saveResumeDataFailed,
        torrentId: 5,
        message: 'save failed',
      ),
    );
    expect(errorId, 5);
    expect(errorMsg, 'save failed');
  });

  test('ignores stateUpdate and unknown alerts', () {
    var called = false;
    final handler = TorrentAlertHandler(
      onFinished: (_) => called = true,
      onError: (_, __) => called = true,
      onFileError: (_, __) => called = true,
      onMetadataReceived: (_) => called = true,
      onSaveResumeData: (_, __) => called = true,
    );

    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.stateUpdate,
        torrentId: 1,
        message: '',
      ),
    );
    handler.handle(
      const TorrentAlert(
        type: 0,
        kind: TorrentAlertKind.unknown,
        torrentId: 1,
        message: '',
      ),
    );
    expect(called, isFalse);
  });
}
