import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';
import 'package:torrent_music/services/p2p/magnet_metadata_preview.dart';
import 'package:torrent_music/services/p2p/session_persistence.dart';
import 'package:torrent_music/services/p2p/torrent_session_config.dart';
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
  final Set<String> _metadataOnlyIds = {};
  final SessionPersistence _sessionPersistence = SessionPersistence();

  LibtorrentFlutter? _engine;
  StreamSubscription<Map<int, TorrentInfo>>? _updatesSub;
  StreamSubscription<TorrentAlert>? _alertsSub;
  bool _initialized = false;
  bool _useNative = false;
  String? _downloadDir;
  List<String> _trackers = [];

  Stream<P2pProgressEvent> get progressStream => _progressController.stream;
  Stream<TorrentAlert> get alertStream =>
      _engine?.alertStream ?? const Stream.empty();
  bool get isNative => _useNative;

  /// Throws when libtorrent failed to initialize on a platform that requires it.
  void requireNative() {
    if (!_useNative && !_allowSimulation) {
      throw StateError('P2P engine failed to start');
    }
  }

  static bool get _allowSimulation {
    if (kIsWeb) return true;
    return !(Platform.isAndroid || Platform.isIOS);
  }

  String? get downloadDir => _downloadDir;
  SessionPersistence get sessionPersistence => _sessionPersistence;

  String? appIdForTorrent(int torrentId) => _torrentToApp[torrentId];

  bool hasHandle(String id) => _appToTorrent.containsKey(id);

  double getProgressForAppId(String appId) {
    if (!_useNative || _engine == null) return 0;
    final torrentId = _appToTorrent[appId];
    if (torrentId == null) return 0;
    return _engine!.torrents[torrentId]?.progress ?? 0;
  }

  bool hasMetadataForAppId(String appId) {
    if (!_useNative || _engine == null) return false;
    final torrentId = _appToTorrent[appId];
    if (torrentId == null) return false;
    return _engine!.torrents[torrentId]?.hasMetadata ?? false;
  }

  bool get hasPostMetadataApi =>
      _useNative && (_engine?.hasPostMetadataApi ?? false);

  Future<void> setDownloadDirectory(String path) async {
    if (!await _verifyWritable(path)) {
      throw StateError('Download directory is not writable: $path');
    }
    _downloadDir = path;
  }

  Future<bool> _verifyWritable(String path) async {
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      final test = File('${dir.path}/.jamp_write_test');
      await test.writeAsString('ok', flush: true);
      await test.delete();
      return true;
    } catch (e, st) {
      AppLog.error('P2pEngine', 'Path not writable $path', e, st);
      return false;
    }
  }

  Future<void> initialize({
    String? downloadDir,
    BtConfig? sessionConfig,
    String? sessionStatePath,
  }) async {
    if (_initialized) {
      if (downloadDir != null && downloadDir != _downloadDir) {
        if (await _verifyWritable(downloadDir)) {
          _downloadDir = downloadDir;
        }
      }
      if (sessionConfig != null && _engine != null) {
        _engine!.configureSession(sessionConfig);
      }
      return;
    }

    _downloadDir = downloadDir;
    if (_downloadDir == null) {
      final docs = await getApplicationDocumentsDirectory();
      _downloadDir = '${docs.path}/Downloads';
    }
    if (!await _verifyWritable(_downloadDir!)) {
      final docs = await getApplicationDocumentsDirectory();
      _downloadDir = '${docs.path}/Downloads';
      await _verifyWritable(_downloadDir!);
    }

    final statePath =
        sessionStatePath ?? await SessionPersistence.existingSessionStatePath();

    try {
      await LibtorrentFlutter.init(
        defaultSavePath: _downloadDir,
        fetchTrackers: false,
        pollInterval: const Duration(milliseconds: 500),
        sessionStatePath: statePath,
      );
      _engine = LibtorrentFlutter.instance;
      _sessionPersistence.bindEngine(_engine!);
      _engine!.configureSession(sessionConfig ?? const BtConfig());
      _updatesSub = _engine!.torrentUpdates.listen(
        _onTorrentUpdates,
        onError: (e, st) =>
            AppLog.error('P2pEngine', 'torrentUpdates stream error', e, st),
      );
      _alertsSub = _engine!.alertStream.listen(
        (alert) => AppLog.p2p(
          alert.kind.name,
          torrentId: '${alert.torrentId}',
          detail: alert.message.isNotEmpty ? alert.message : null,
        ),
        onError: (e, st) =>
            AppLog.error('P2pEngine', 'alertStream error', e, st),
      );
      _useNative = true;
      AppLog.sys('P2pEngine: libtorrent initialized at $_downloadDir');
    } catch (e, st) {
      AppLog.error(
        'P2pEngine',
        _allowSimulation
            ? 'libtorrent unavailable, using simulation'
            : 'libtorrent unavailable',
        e,
        st,
      );
      if (!_allowSimulation) {
        rethrow;
      }
      _useNative = false;
    }

    _initialized = true;
  }

  Future<void> addMagnet(
    String magnet, {
    required String id,
    bool metadataOnly = false,
    Uint8List? resumeData,
  }) async {
    await initialize();
    requireNative();
    if (_useNative && _engine != null) {
      if (_downloadDir == null || !await _verifyWritable(_downloadDir!)) {
        throw StateError('Download directory is not writable');
      }
      final savePath = _downloadDir!;
      try {
        final torrentId = resumeData != null && resumeData.isNotEmpty
            ? _engine!.addMagnetWithResume(
                magnet,
                resumeData,
                savePath,
                metadataOnly,
              )
            : _engine!.addMagnet(
                magnet,
                savePath,
                metadataOnly,
              );
        if (torrentId < 0) {
          throw StateError('libtorrent rejected magnet');
        }
        _appToTorrent[id] = torrentId;
        _torrentToApp[torrentId] = id;
        if (metadataOnly) _metadataOnlyIds.add(id);
        return;
      } catch (e, st) {
        AppLog.error('P2pEngine', 'addMagnet native error', e, st);
        rethrow;
      }
    }
    _startSimulatedDownload(id, magnet, metadataOnly: metadataOnly);
  }

  /// Resume piece download after metadata-only (stream) fetch completes.
  Future<void> beginPieceDownload(String id) async {
    _metadataOnlyIds.remove(id);
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent[id];
      if (torrentId == null) return;
      try {
        if (_engine!.hasPostMetadataApi) {
          _engine!.beginPieceDownloadNative(torrentId);
        } else {
          _engine!.resumeTorrent(torrentId);
        }
        _audioPrioritized.remove(torrentId);
        prioritizeAudioFiles(_engine!, torrentId);
      } catch (e, st) {
        AppLog.error('P2pEngine', 'beginPieceDownload failed', e, st);
        rethrow;
      }
      return;
    }
    final active = _simulated[id];
    if (active != null && active.awaitingMetadata) {
      _startSimulatedDownload(
        id,
        active.source,
        metadataOnly: false,
        resumeFrom: active.progress,
      );
    }
  }

  bool isMetadataOnly(String id) => _metadataOnlyIds.contains(id);

  Future<void> addTorrentFile(String path, {required String id}) async {
    await initialize();
    if (_useNative && _engine != null) {
      final savePath = _downloadDir!;
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

  Future<void> reannounceTorrent(String id) async {
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent[id];
      if (torrentId == null) return;
      try {
        _engine!.pauseTorrent(torrentId);
        _engine!.resumeTorrent(torrentId);
      } catch (e, st) {
        AppLog.error('P2pEngine', 'reannounceTorrent failed', e, st);
      }
      return;
    }
    final active = _simulated[id];
    if (active != null) {
      _emitProgress(
        P2pProgressEvent(
          id: id,
          progress: active.progress,
          downloadBps: 0,
          uploadBps: 0,
          numSeeds: 12,
          numPeers: 3,
        ),
      );
    }
  }

  void requestSaveResumeData(String appId) {
    if (!_useNative || _engine == null) return;
    final torrentId = _appToTorrent[appId];
    if (torrentId == null) return;
    _engine!.requestSaveResumeData(torrentId);
  }

  Uint8List takeResumeData(String appId) {
    if (!_useNative || _engine == null) return Uint8List(0);
    final torrentId = _appToTorrent[appId];
    if (torrentId == null) return Uint8List(0);
    return _engine!.takeResumeData(torrentId);
  }

  Future<bool> saveSessionState() => _sessionPersistence.save();

  Future<void> remove(String id, {bool deleteFiles = false}) async {
    _metadataOnlyIds.remove(id);
    if (_useNative && _engine != null) {
      final torrentId = _appToTorrent.remove(id);
      if (torrentId != null) {
        _torrentToApp.remove(torrentId);
        _audioPrioritized.remove(torrentId);
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
  }

  Future<void> injectTrackers(String appId, List<String> trackers) async {
    if (!_useNative || _engine == null || trackers.isEmpty) return;
    final torrentId = _appToTorrent[appId];
    if (torrentId == null) return;
    try {
      if (_engine!.hasPostMetadataApi) {
        _engine!.addTrackers(torrentId, trackers);
        _engine!.forceReannounce(torrentId);
      } else {
        await reannounceTorrent(appId);
      }
    } catch (e, st) {
      AppLog.error('P2pEngine', 'injectTrackers failed', e, st);
    }
  }

  Future<void> reannounceAll() async {
    if (_useNative && _engine != null) {
      for (final entry in _appToTorrent.entries) {
        try {
          _engine!.pauseTorrent(entry.value);
          _engine!.resumeTorrent(entry.value);
        } catch (e, st) {
          AppLog.error('P2pEngine', 'reannounce pause/resume failed', e, st);
        }
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

  static int _clampPeerCount(int count) => count < 0 ? 0 : count;

  void _onTorrentUpdates(Map<int, TorrentInfo> torrents) {
    for (final entry in torrents.entries) {
      try {
        final appId = _torrentToApp[entry.key];
        if (appId == null) continue;

        final info = entry.value;

        if (info.state == TorrentState.error && info.errorMsg.isNotEmpty) {
          _emitProgress(
            P2pProgressEvent(
              id: appId,
              progress: info.progress.clamp(0.0, 1.0),
              downloadBps: 0,
              uploadBps: 0,
              numSeeds: _clampPeerCount(info.numSeeds),
              numPeers: _clampPeerCount(info.numPeers),
              seedsKnown: info.numSeeds >= 0,
              peersKnown: info.numPeers >= 0,
              isFailed: true,
              errorMessage: info.errorMsg,
              phaseLabel: torrentPhaseLabel(info.state),
              hasMetadata: info.hasMetadata,
              displayName: info.name.isNotEmpty ? info.name : null,
            ),
          );
          continue;
        }

        if (info.hasMetadata && !_audioPrioritized.contains(entry.key)) {
          if (!_metadataOnlyIds.contains(appId) && _engine != null) {
            prioritizeAudioFiles(_engine!, entry.key);
          }
          _audioPrioritized.add(entry.key);
        }

        final metadataOnly = _metadataOnlyIds.contains(appId);
        final phaseLabel = metadataOnly && !info.hasMetadata
            ? kDownloadingMetadataLabel
            : torrentPhaseLabel(info.state);

        final completed = isTorrentComplete(info) &&
            (!metadataOnly || info.progress >= 0.99);
        List<FileInfo> files = const [];
        if (completed && info.hasMetadata && _engine != null) {
          try {
            files = _engine!.getFiles(entry.key);
          } catch (e, st) {
            AppLog.error('P2pEngine', 'getFiles failed', e, st);
          }
        }

        _emitProgress(
          P2pProgressEvent(
            id: appId,
            progress: info.progress.clamp(0.0, 1.0),
            downloadBps: info.downloadRate,
            uploadBps: info.uploadRate,
            numSeeds: _clampPeerCount(info.numSeeds),
            numPeers: _clampPeerCount(info.numPeers),
            seedsKnown: info.numSeeds >= 0,
            peersKnown: info.numPeers >= 0,
            isCompleted: completed,
            savePath: completed ? musicImportPath(info, files) : info.savePath,
            displayName: info.name.isNotEmpty ? info.name : null,
            phaseLabel: phaseLabel,
            hasMetadata: info.hasMetadata,
          ),
        );
      } catch (e, st) {
        AppLog.error('P2pEngine', 'Torrent update failed', e, st);
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
    bool metadataOnly = false,
  }) {
    _simulated[id]?.timer?.cancel();

    if (metadataOnly) {
      _metadataOnlyIds.add(id);
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        ticks++;
        final hasMetadata = ticks >= 4;
        _simulated[id] = _ActiveDownload(
          source: source,
          progress: 0,
          timer: hasMetadata ? null : timer,
          awaitingMetadata: !hasMetadata,
        );
        _emitProgress(
          P2pProgressEvent(
            id: id,
            progress: 0,
            downloadBps: 0,
            uploadBps: 0,
            numSeeds: 0,
            numPeers: 0,
            hasMetadata: hasMetadata,
            displayName: hasMetadata ? 'Simulated release' : null,
            phaseLabel: hasMetadata
                ? torrentPhaseLabel(TorrentState.downloading)
                : kDownloadingMetadataLabel,
          ),
        );
        if (hasMetadata) timer.cancel();
      });
      _simulated[id] = _ActiveDownload(
        source: source,
        progress: 0,
        timer: timer,
        awaitingMetadata: true,
      );
      return;
    }

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
    await _alertsSub?.cancel();
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
  _ActiveDownload({
    required this.source,
    required this.progress,
    this.timer,
    this.awaitingMetadata = false,
  });

  final String source;
  final double progress;
  final Timer? timer;
  final bool awaitingMetadata;
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
    this.isFailed = false,
    this.savePath,
    this.displayName,
    this.phaseLabel,
    this.errorMessage,
    this.hasMetadata = false,
    this.seedsKnown = true,
    this.peersKnown = true,
  });

  final String id;
  final double progress;
  final int downloadBps;
  final int uploadBps;
  final int numSeeds;
  final int numPeers;
  final bool isCompleted;
  final bool isFailed;
  final String? savePath;
  final String? displayName;
  final String? phaseLabel;
  final String? errorMessage;
  final bool hasMetadata;
  final bool seedsKnown;
  final bool peersKnown;
}
