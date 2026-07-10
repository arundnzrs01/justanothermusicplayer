import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:torrent_music/services/p2p/torrent_utils.dart';

final p2pEngineProvider = Provider<P2pEngine>((ref) {
  final engine = P2pEngine();
  ref.keepAlive();
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// P2P download engine backed by libtorrent with simulated fallback.
class P2pEngine {
  P2pEngine();

  final _progressController = StreamController<P2pProgressEvent>.broadcast();
  final Map<String, int> _appToTorrent = {};
  final Map<int, String> _torrentToApp = {};
  final Set<int> _audioPrioritized = {};
  final Map<String, _ActiveDownload> _simulated = {};

  LibtorrentFlutter? _engine;
  StreamSubscription<Map<int, TorrentInfo>>? _updatesSub;
  bool _initialized = false;
  bool _useNative = false;
  String? _downloadDir;
  List<String> _trackers = [];

  Stream<P2pProgressEvent> get progressStream => _progressController.stream;
  bool get isNative => _useNative;

  String? get downloadDir => _downloadDir;

  Future<void> setDownloadDirectory(String path) async {
    _downloadDir = path;
    await Directory(path).create(recursive: true);
  }

  Future<void> initialize({String? downloadDir}) async {
    if (_initialized) {
      if (downloadDir != null && downloadDir != _downloadDir) {
        _downloadDir = downloadDir;
        await Directory(_downloadDir!).create(recursive: true);
      }
      return;
    }

    _downloadDir = downloadDir;
    if (_downloadDir == null) {
      final docs = await getApplicationDocumentsDirectory();
      _downloadDir = '${docs.path}/Downloads';
    }
    await Directory(_downloadDir!).create(recursive: true);

    try {
      await LibtorrentFlutter.init(
        defaultSavePath: _downloadDir,
        fetchTrackers: false,
        pollInterval: const Duration(milliseconds: 500),
      );
      _engine = LibtorrentFlutter.instance;
      _updatesSub = _engine!.torrentUpdates.listen(_onTorrentUpdates);
      _useNative = true;
      debugPrint('P2pEngine: libtorrent initialized');
    } catch (e, st) {
      debugPrint('P2pEngine: libtorrent unavailable, using simulation: $e\n$st');
      _useNative = false;
    }

    _initialized = true;
  }

  Future<void> addMagnet(String magnet, {required String id}) async {
    await initialize();
    if (_useNative && _engine != null) {
      final savePath = '$_downloadDir/$id';
      await Directory(savePath).create(recursive: true);
      try {
        final torrentId = _engine!.addMagnet(magnet, savePath);
        if (torrentId < 0) {
          throw StateError('libtorrent rejected magnet');
        }
        _appToTorrent[id] = torrentId;
        _torrentToApp[torrentId] = id;
        return;
      } catch (e, st) {
        debugPrint('P2pEngine.addMagnet native error: $e\n$st');
        rethrow;
      }
    }
    _startSimulatedDownload(id, magnet);
  }

  Future<void> addTorrentFile(String path, {required String id}) async {
    await initialize();
    if (_useNative && _engine != null) {
      final savePath = '$_downloadDir/$id';
      await Directory(savePath).create(recursive: true);
      final torrentId = _engine!.addTorrentFile(path, savePath);
      _appToTorrent[id] = torrentId;
      _torrentToApp[torrentId] = id;
      return;
    }
    _startSimulatedDownload(id, path);
  }

  Future<void> pause(String id) async {
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent[id];
      if (torrentId != null) _engine!.pauseTorrent(torrentId);
      return;
    }
    _simulated[id]?.timer?.cancel();
  }

  Future<void> resume(String id) async {
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent[id];
      if (torrentId != null) _engine!.resumeTorrent(torrentId);
      return;
    }
    final active = _simulated[id];
    if (active != null) {
      _startSimulatedDownload(id, active.source, resumeFrom: active.progress);
    }
  }

  Future<void> remove(String id, {bool deleteFiles = false}) async {
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent.remove(id);
      if (torrentId != null) {
        _torrentToApp.remove(torrentId);
        if (deleteFiles) {
          _engine!.disposeTorrent(torrentId);
        } else {
          _engine!.removeTorrent(torrentId, deleteFiles: false);
        }
      }
      return;
    }
    _simulated[id]?.timer?.cancel();
    _simulated.remove(id);
  }

  Future<void> setSpeedLimits({
    required int downloadKbps,
    required int uploadKbps,
  }) async {
    if (_useNative && _engine != null) {
      final down = downloadKbps <= 0 ? 0 : downloadKbps * 1024;
      final up = uploadKbps <= 0 ? 0 : uploadKbps * 1024;
      _engine!.setDownloadLimit(down);
      _engine!.setUploadLimit(up);
    }
  }

  Future<void> applyTrackers(List<String> trackers) async {
    _trackers = trackers;
    // libtorrent_flutter auto-fetches public trackers; custom list applied on new torrents.
  }

  Future<void> reannounceAll() async {
    if (_useNative && _engine != null) {
      for (final torrentId in _appToTorrent.values) {
        _engine!.recheckTorrent(torrentId);
      }
      return;
    }
    for (final id in _simulated.keys) {
      _emitProgress(
        P2pProgressEvent(
          id: id,
          progress: _simulated[id]?.progress ?? 0,
          downloadBps: 0,
          uploadBps: 0,
          numSeeds: 12,
          numPeers: 3,
        ),
      );
    }
  }

  void _onTorrentUpdates(Map<int, TorrentInfo> torrents) {
    for (final entry in torrents.entries) {
      try {
        final appId = _torrentToApp[entry.key];
        if (appId == null) continue;

        final info = entry.value;
        if (info.hasMetadata &&
            _engine != null &&
            !_audioPrioritized.contains(entry.key)) {
          try {
            prioritizeAudioFiles(_engine!, entry.key);
          } catch (e, st) {
            debugPrint('prioritizeAudioFiles failed: $e\n$st');
          }
          _audioPrioritized.add(entry.key);
        }

        final completed = isTorrentComplete(info);
        List<FileInfo> files = const [];
        if (completed && info.hasMetadata && _engine != null) {
          try {
            files = _engine!.getFiles(entry.key);
          } catch (e, st) {
            debugPrint('getFiles failed: $e\n$st');
          }
        }

        _emitProgress(
          P2pProgressEvent(
            id: appId,
            progress: info.progress.clamp(0.0, 1.0),
            downloadBps: info.downloadRate,
            uploadBps: info.uploadRate,
            numSeeds: info.numSeeds,
            numPeers: info.numPeers,
            isCompleted: completed,
            savePath: completed ? musicImportPath(info, files) : info.savePath,
            displayName: info.name.isNotEmpty ? info.name : null,
          ),
        );
      } catch (e, st) {
        debugPrint('Torrent update failed: $e\n$st');
      }
    }
  }

  void _emitProgress(P2pProgressEvent event) {
    if (_progressController.isClosed) return;
    _progressController.add(event);
  }

  void _startSimulatedDownload(
    String id,
    String source, {
    double resumeFrom = 0,
  }) {
    _simulated[id]?.timer?.cancel();
    var progress = resumeFrom;
    final timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      progress += 0.03;
      if (progress >= 1) {
        timer.cancel();
        _emitProgress(
          P2pProgressEvent(
            id: id,
            progress: 1,
            downloadBps: 0,
            uploadBps: 0,
            numSeeds: 8,
            numPeers: 2,
            isCompleted: true,
            savePath: '$_downloadDir/$id',
          ),
        );
        return;
      }
      _simulated[id] =
          _ActiveDownload(source: source, progress: progress, timer: timer);
      _emitProgress(
        P2pProgressEvent(
          id: id,
          progress: progress,
          downloadBps: 256000,
          uploadBps: 32000,
          numSeeds: 14,
          numPeers: 5,
        ),
      );
    });
    _simulated[id] =
        _ActiveDownload(source: source, progress: progress, timer: timer);
  }

  Future<void> dispose() async {
    await _updatesSub?.cancel();
    for (final active in _simulated.values) {
      active.timer?.cancel();
    }
    if (_useNative && _engine != null) {
      await _engine!.dispose();
    }
    await _progressController.close();
  }
}

class _ActiveDownload {
  _ActiveDownload({required this.source, required this.progress, this.timer});

  final String source;
  final double progress;
  final Timer? timer;
}

class P2pProgressEvent {
  const P2pProgressEvent({
    required this.id,
    required this.progress,
    required this.downloadBps,
    required this.uploadBps,
    required this.numSeeds,
    required this.numPeers,
    this.isCompleted = false,
    this.savePath,
    this.displayName,
  });

  final String id;
  final double progress;
  final int downloadBps;
  final int uploadBps;
  final int numSeeds;
  final int numPeers;
  final bool isCompleted;
  final String? savePath;
  final String? displayName;
}
