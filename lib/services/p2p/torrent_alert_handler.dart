import 'dart:typed_data';

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

typedef TorrentAlertCallback = void Function(int torrentId);
typedef TorrentAlertMessageCallback = void Function(int torrentId, String message);
typedef TorrentSaveResumeCallback = void Function(int torrentId, Uint8List bytes);

/// Dispatches libtorrent [TorrentAlert] events to app callbacks.
class TorrentAlertHandler {
  TorrentAlertHandler({
    required this.onFinished,
    required this.onError,
    required this.onFileError,
    required this.onMetadataReceived,
    required this.onSaveResumeData,
    this.takeResumeData,
  });

  final TorrentAlertCallback onFinished;
  final TorrentAlertMessageCallback onError;
  final TorrentAlertMessageCallback onFileError;
  final TorrentAlertCallback onMetadataReceived;
  final TorrentSaveResumeCallback onSaveResumeData;

  /// When set, resume bytes are read from the engine on [TorrentAlertKind.saveResumeData].
  final Uint8List Function(int torrentId)? takeResumeData;

  void handle(TorrentAlert alert) {
    switch (alert.kind) {
      case TorrentAlertKind.finished:
        onFinished(alert.torrentId);
      case TorrentAlertKind.error:
        onError(alert.torrentId, alert.message);
      case TorrentAlertKind.fileError:
        onFileError(alert.torrentId, alert.message);
      case TorrentAlertKind.metadataReceived:
        onMetadataReceived(alert.torrentId);
      case TorrentAlertKind.saveResumeData:
        _handleSaveResumeData(alert.torrentId);
      case TorrentAlertKind.saveResumeDataFailed:
        onError(alert.torrentId, alert.message);
      case TorrentAlertKind.stateUpdate:
      case TorrentAlertKind.added:
      case TorrentAlertKind.unknown:
        break;
    }
  }

  void _handleSaveResumeData(int torrentId) {
    final reader = takeResumeData;
    if (reader == null) return;
    final bytes = reader(torrentId);
    if (bytes.isEmpty) return;
    onSaveResumeData(torrentId, bytes);
  }
}
