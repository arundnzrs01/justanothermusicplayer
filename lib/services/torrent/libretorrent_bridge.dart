import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform bridge to libtorrent4j on Android (same engine as LibreTorrent).
class LibreTorrentBridge {
  LibreTorrentBridge._();

  static const _method = MethodChannel('com.torrentmusic/torrent');
  static const _events = EventChannel('com.torrentmusic/torrent_events');

  static final LibreTorrentBridge instance = LibreTorrentBridge._();

  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<List<TorrentSnapshot>>.broadcast();

  Stream<List<TorrentSnapshot>> get updates => _controller.stream;

  Future<String> initialize(String savePath) async {
    final path = await _method.invokeMethod<String>('initialize', {
      'savePath': savePath,
    });
    return path ?? savePath;
  }

  void startListening() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is! List) return;
        final items = event
            .whereType<Map>()
            .map((m) => TorrentSnapshot.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _controller.add(items);
      },
      onError: (e, st) => debugPrint('torrent events error: $e\n$st'),
    );
  }

  Future<String> addMagnet(String magnet) async {
    return await _method.invokeMethod<String>('addMagnet', {'magnet': magnet}) ??
        '';
  }

  Future<String> addTorrentFile(String path) async {
    return await _method.invokeMethod<String>('addTorrentFile', {'path': path}) ??
        '';
  }

  Future<void> pause(String id) =>
      _method.invokeMethod('pause', {'id': id});

  Future<void> resume(String id) =>
      _method.invokeMethod('resume', {'id': id});

  Future<void> remove(String id, {bool deleteFiles = false}) =>
      _method.invokeMethod('remove', {'id': id, 'deleteFiles': deleteFiles});

  Future<void> shutdown() async {
    await _sub?.cancel();
    _sub = null;
    await _method.invokeMethod('shutdown');
  }

  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_controller.close());
  }
}

class TorrentSnapshot {
  const TorrentSnapshot({
    required this.id,
    required this.displayName,
    required this.progress,
    required this.downloadBps,
    required this.uploadBps,
    required this.seeders,
    required this.leechers,
    required this.status,
    this.phaseLabel,
    this.errorMessage,
  });

  final String id;
  final String displayName;
  final double progress;
  final int downloadBps;
  final int uploadBps;
  final int seeders;
  final int leechers;
  final String status;
  final String? phaseLabel;
  final String? errorMessage;

  factory TorrentSnapshot.fromMap(Map<String, dynamic> map) {
    return TorrentSnapshot(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Download',
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      downloadBps: (map['downloadBps'] as num?)?.toInt() ?? 0,
      uploadBps: (map['uploadBps'] as num?)?.toInt() ?? 0,
      seeders: (map['seeders'] as num?)?.toInt() ?? 0,
      leechers: (map['leechers'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'downloading',
      phaseLabel: map['phaseLabel'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
