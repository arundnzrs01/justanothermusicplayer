import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' hide TrackerManager;
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/library_scanner.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';
import 'package:torrent_music/services/logging/log_sanitizer.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/services/p2p/download_persistence.dart';
import 'package:torrent_music/services/p2p/magnet_link.dart';
import 'package:torrent_music/services/p2p/magnet_metadata_preview.dart';
import 'package:torrent_music/services/p2p/peer_bootstrap.dart';
import 'package:torrent_music/services/p2p/p2p_engine.dart';
import 'package:torrent_music/services/p2p/session_persistence.dart';
import 'package:torrent_music/services/p2p/torrent_alert_handler.dart';
import 'package:torrent_music/services/p2p/torrent_session_config.dart';
import 'package:torrent_music/services/p2p/tracker_manager.dart';
import 'package:uuid/uuid.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    engine: ref.read(p2pEngineProvider),
    trackerManager: ref.read(trackerManagerProvider),
    database: ref.read(databaseProvider),
    scanner: ref.read(libraryScannerProvider),
    connectivity: ref.read(connectivityServiceProvider),
    settings: ref.read(appSettingsProvider),
    directoryService: ref.read(downloadDirectoryServiceProvider),
  );

  ref.listen(appSettingsProvider, (previous, next) {
    manager.updateSettings(next);
  });

  ref.onDispose(manager.dispose);
  ref.keepAlive();
  return manager;
});

class DownloadManager {
  DownloadManager({
    required P2pEngine engine,
    required TrackerManager trackerManager,
    required AppDatabase database,
    required LibraryScanner scanner,
    required ConnectivityService connectivity,
    required AppSettings settings,
    required DownloadDirectoryService directoryService,
  })  : _engine = engine,
        _trackerManager = trackerManager,
        _database = database,
        _scanner = scanner,
        _connectivity = connectivity,
        _settings = settings,
        _directoryService = directoryService {
    _emit();
    _init();
  }

  final P2pEngine _engine;
  final TrackerManager _trackerManager;
  final AppDatabase _database;
  final LibraryScanner _scanner;
  final ConnectivityService _connectivity;
  AppSettings _settings;
  final DownloadDirectoryService _directoryService;

  final _uuid = const Uuid();
  late final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast(
    onListen: _pushCurrentItems,
  );
  final List<DownloadItem> _items = [];
  StreamSubscription<bool>? _wifiSub;
  StreamSubscription<P2pProgressEvent>? _progressSub;
  bool _disposed = false;
  late final Future<void> _ready = _init();
  final Map<String, DateTime> _bootstrapStarted = {};
  final Set<String> _staleRefreshAttempted = {};
  final Set<String> _prefetchIds = {};
  final Set<String> _awaitingPieceDownload = {};
  final Map<String, StreamController<MagnetMetadataPreview>> _prefetchStreams = {};
  final Map<String, MagnetMetadataPreview> _prefetchLatest = {};
  String? _activePrefetchId;
  String? _activePrefetchMagnet;
  DownloadPersistence? _persistence;
  late SessionPersistence _sessionPersistence;
  TorrentAlertHandler? _alertHandler;
  StreamSubscription<TorrentAlert>? _alertSub;
  Timer? _resumeSaveTimer;
  final Map<String, int> _metadataGeneration = {};
  final Map<String, DateTime> _metadataReceivedAt = {};
  static const _stalePeerTimeout = Duration(seconds: 60);
  static const _metadataTimeout = Duration(minutes: 3);
  static const _stallTimeout = Duration(minutes: 5);

  Stream<List<DownloadItem>> get downloads => _controller.stream;

  List<DownloadItem> get currentItems => List.unmodifiable(_items);
  String get trackerListUrl => _trackerManager.listUrl;
  List<String> get trackers => List.unmodifiable(_trackerManager.trackers);
  bool get wifiOnly => _settings.wifiOnlyDownloads;
  String? get downloadDirectory => _engine.downloadDir;
  DateTime? get trackersLastUpdated => _trackerManager.lastUpdatedAt;

  Future<void> _init() async {
    _emit();

    try {
      final dir = await _resolveAndPrepareDownloadDir();
      final sessionStatePath =
          await SessionPersistence.existingSessionStatePath();
      await _engine.initialize(
        downloadDir: dir,
        sessionConfig: TorrentSessionConfig.forSettings(_settings),
        sessionStatePath: sessionStatePath,
      );
      _sessionPersistence = _engine.sessionPersistence;
      await _sessionPersistence.ensureDirectory();

      _persistence = DownloadPersistence(
        database: _database,
        downloadDir: dir,
      );
      final loaded = await _persistence!.loadAll();
      _items.addAll(loaded);

      await _trackerManager.load();

      _progressSub = _engine.progressStream.listen(_onEngineProgress);

      _alertHandler = TorrentAlertHandler(
        onFinished: (torrentId) {
          final appId = _engine.appIdForTorrent(torrentId);
          if (appId == null) return;
          AppLog.p2p('finished', torrentId: appId);
        },
        onError: (torrentId, message) {
          final appId = _engine.appIdForTorrent(torrentId);
          AppLog.p2p(
            'error',
            torrentId: appId ?? '$torrentId',
            detail: message,
          );
        },
        onFileError: (torrentId, message) {
          final appId = _engine.appIdForTorrent(torrentId);
          AppLog.p2p(
            'fileError',
            torrentId: appId ?? '$torrentId',
            detail: message,
          );
        },
        onMetadataReceived: (torrentId) {
          final appId = _engine.appIdForTorrent(torrentId);
          if (appId != null) {
            _metadataReceivedAt[appId] = DateTime.now();
          }
          AppLog.p2p('metadataReceived', torrentId: appId ?? '$torrentId');
        },
        onSaveResumeData: (torrentId, bytes) {
          unawaited(_onSaveResumeData(torrentId, bytes));
        },
        takeResumeData: (torrentId) {
          final appId = _engine.appIdForTorrent(torrentId);
          if (appId == null) return Uint8List(0);
          return _engine.takeResumeData(appId);
        },
      );
      _alertSub = _engine.alertStream.listen(_alertHandler!.handle);

      _resumeSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        for (final item in _items) {
          if (item.status == DownloadStatus.downloading &&
              _engine.hasHandle(item.id)) {
            _engine.requestSaveResumeData(item.id);
          }
        }
      });

      final down = _settings.downloadLimitKbps;
      final up = _settings.uploadLimitKbps;
      if (down > 0 || up > 0) {
        await _engine.setSpeedLimits(downloadKbps: down, uploadKbps: up);
      }
      if (_trackerManager.trackers.isNotEmpty) {
        await _engine.applyTrackers(_trackerManager.trackers);
      }

      _wifiSub = _connectivity.onWifiChanged.listen((onWifi) {
        if (!_settings.wifiOnlyDownloads) return;
        if (onWifi) {
          unawaited(_resumeWifiBlocked());
        } else {
          unawaited(_pauseForWifi());
        }
      });
    } catch (e, st) {
      AppLog.error('DownloadManager', 'init error', e, st);
    } finally {
      _emit();
    }

    unawaited(_refreshTrackersInBackground());
  }

  Future<void> _onSaveResumeData(int torrentId, Uint8List bytes) async {
    final appId = _engine.appIdForTorrent(torrentId);
    if (appId == null || bytes.isEmpty) return;
    final item = _find(appId);
    if (item == null) return;
    await _persistence?.writeResume(item.magnetOrHash, bytes);
    AppLog.p2p('resumeSaved', torrentId: appId, detail: 'bytes=${bytes.length}');
  }

  Future<String> _resolveAndPrepareDownloadDir() async {
    final configured = _settings.downloadDirectoryPath;
    final dir = await _directoryService.resolvePath(configured);
    if (_directoryService.didMigrate(configured, dir)) {
      debugPrint('Migrated download folder to writable path: $dir');
      _settings = _settings.copyWith(clearDownloadDirectory: true);
      await _database.setSetting('download_directory_path', '');
    }
    await _engine.setDownloadDirectory(dir);
    return dir;
  }

  Future<void> _refreshTrackersInBackground() async {
    try {
      final updated = await _trackerManager.maybeAutoRefresh(
        enabled: _settings.autoUpdateTrackersDaily,
      );
      if (updated || _trackerManager.trackers.isNotEmpty) {
        await _engine.applyTrackers(_trackerManager.trackers);
      }
    } catch (e, st) {
      debugPrint('Background tracker refresh failed: $e\n$st');
    }
  }

  Future<bool> _canDownloadNow() async {
    if (!_settings.wifiOnlyDownloads) return true;
    return _connectivity.checkIsOnWifi();
  }

  Future<bool> addMagnet(
    String magnet, {
    String? displayName,
    String? sourceName,
    int seeders = 0,
    int leechers = 0,
    List<String>? extraTrackers,
    bool metadataFirst = true,
  }) async {
    await _ready;
    _engine.requireNative();

    final sanitized = sanitizeMagnetInput(magnet);
    final parsed = MagnetLink.parse(sanitized);
    if (parsed == null) {
      throw ArgumentError('Invalid magnet link — could not read infohash');
    }

    final id = _uuid.v4();
    final perDownload = extraTrackers ?? await _trackerManager.getPerDownloadTrackers(id);
    final enhancedMagnet = PeerBootstrap.prepareMagnet(
      parsed.toUri(maxTrackers: parsed.trackers.length.clamp(0, 20)),
      globalTrackers: _trackerManager.trackers,
      perDownloadTrackers: perDownload,
    );

    AppLog.task(
      'addMagnet',
      id: id,
      phase: 'start',
      detail: 'infohash=${parsed.infoHashHex.substring(0, 8)}…',
    );

    final canStart = await _canDownloadNow();
    final item = DownloadItem(
      id: id,
      displayName: displayName ?? parsed.displayName ?? 'Download',
      magnetOrHash: enhancedMagnet,
      status: canStart ? DownloadStatus.queued : DownloadStatus.paused,
      sourceName: sourceName,
      seeders: seeders,
      leechers: leechers,
      createdAt: DateTime.now(),
      trackers: perDownload,
      waitingForWifi: !canStart,
      errorMessage: canStart ? null : 'Waiting for Wi-Fi',
      phaseLabel: metadataFirst && canStart ? kDownloadingMetadataLabel : null,
    );
    _items.insert(0, item);
    _emit();

    if (!canStart) return true;

    try {
      await _resolveAndPrepareDownloadDir();
      final resume = await _persistence?.readResume(enhancedMagnet);
      _metadataGeneration[id] = (_metadataGeneration[id] ?? 0) + 1;
      await _engine.addMagnet(
        enhancedMagnet,
        id: id,
        metadataOnly: metadataFirst,
        resumeData: resume,
      );
      _bootstrapStarted[id] = DateTime.now();
      _staleRefreshAttempted.remove(id);
      if (metadataFirst) {
        _awaitingPieceDownload.add(id);
      }
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          phaseLabel: metadataFirst
              ? kDownloadingMetadataLabel
              : parsed.hasTrackers
                  ? 'Contacting trackers…'
                  : 'Searching DHT for peers…',
        ),
      );
      return true;
    } catch (e, st) {
      AppLog.error('DownloadManager', 'addMagnet failed', e, st);
      final message = e is StateError
          ? 'Download folder is not writable — check Settings → Storage'
          : 'Failed to start download';
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.failed,
          errorMessage: message,
        ),
      );
      return false;
    }
  }

  /// Resolve magnet metadata in the background (not added to downloads yet).
  Stream<MagnetMetadataPreview> prefetchMetadata(String magnet) {
    final controller = StreamController<MagnetMetadataPreview>.broadcast(
      onCancel: () {
        if (_activePrefetchId != null) {
          unawaited(cancelMetadataPrefetch(_activePrefetchId!));
        }
      },
    );
    unawaited(_runMetadataPrefetch(magnet.trim(), controller));
    return controller.stream;
  }

  Future<void> _runMetadataPrefetch(
    String magnet,
    StreamController<MagnetMetadataPreview> controller,
  ) async {
    await _ready;

    AppLog.input(sanitizeMagnetPaste(magnet));

    if (_activePrefetchId != null) {
      await cancelMetadataPrefetch(_activePrefetchId!);
    }

    final sanitized = sanitizeMagnetInput(magnet);
    if (sanitized.isEmpty) {
      if (!controller.isClosed) {
        controller.add(
          MagnetMetadataPreview(
            prefetchId: '',
            isValid: false,
            errorMessage: 'Paste a magnet link',
          ),
        );
      }
      return;
    }

    final parsed = MagnetLink.parse(sanitized);
    if (parsed == null) {
      if (!controller.isClosed) {
        controller.add(
          MagnetMetadataPreview(
            prefetchId: '',
            isValid: false,
            errorMessage: 'Invalid magnet link — could not read infohash',
          ),
        );
      }
      return;
    }

    final prefetchId = _uuid.v4();
    _activePrefetchId = prefetchId;
    _activePrefetchMagnet = sanitized;
    _prefetchIds.add(prefetchId);
    _prefetchStreams[prefetchId] = controller;

    final perDownload = await _trackerManager.getPerDownloadTrackers(prefetchId);
    final enhancedMagnet = PeerBootstrap.prepareMagnet(
      parsed.toUri(maxTrackers: parsed.trackers.length.clamp(0, 20)),
      globalTrackers: _trackerManager.trackers,
      perDownloadTrackers: perDownload,
    );

    if (!controller.isClosed) {
      controller.add(
        MagnetMetadataPreview(
          prefetchId: prefetchId,
          isLoading: true,
          displayName: parsed.displayName,
          phaseLabel: kDownloadingMetadataLabel,
        ),
      );
    }

    try {
      await _resolveAndPrepareDownloadDir();
      await _engine.addMagnet(
        enhancedMagnet,
        id: prefetchId,
        metadataOnly: true,
      );
    } catch (e, st) {
      AppLog.error('DownloadManager', 'prefetchMetadata failed', e, st);
      _clearPrefetch(prefetchId);
      if (!controller.isClosed) {
        controller.add(
          MagnetMetadataPreview(
            prefetchId: prefetchId,
            isValid: false,
            errorMessage: 'Failed to fetch metadata',
          ),
        );
        await controller.close();
      }
    }
  }

  Future<void> cancelMetadataPrefetch(String prefetchId) async {
    if (!_prefetchIds.contains(prefetchId)) return;
    await _engine.remove(prefetchId, deleteFiles: true);
    _clearPrefetch(prefetchId);
  }

  void _clearPrefetch(String prefetchId) {
    _prefetchIds.remove(prefetchId);
    _prefetchLatest.remove(prefetchId);
    final stream = _prefetchStreams.remove(prefetchId);
    if (_activePrefetchId == prefetchId) {
      _activePrefetchId = null;
      _activePrefetchMagnet = null;
    }
    unawaited(stream?.close());
  }

  Future<bool> commitPrefetchedDownload(String prefetchId) async {
    await _ready;
    if (!_prefetchIds.contains(prefetchId)) return false;

    final magnet = _activePrefetchMagnet;
    if (magnet == null) return false;

    final sanitized = sanitizeMagnetInput(magnet);
    final parsed = MagnetLink.parse(sanitized);
    if (parsed == null) return false;

    final perDownload = await _trackerManager.getPerDownloadTrackers(prefetchId);
    final enhancedMagnet = PeerBootstrap.prepareMagnet(
      parsed.toUri(maxTrackers: parsed.trackers.length.clamp(0, 20)),
      globalTrackers: _trackerManager.trackers,
      perDownloadTrackers: perDownload,
    );

    final canStart = await _canDownloadNow();
    final preview = _prefetchLatest.remove(prefetchId);
    final item = DownloadItem(
      id: prefetchId,
      displayName: preview?.displayName ?? parsed.displayName ?? 'Download',
      magnetOrHash: enhancedMagnet,
      status: canStart ? DownloadStatus.downloading : DownloadStatus.paused,
      createdAt: DateTime.now(),
      trackers: perDownload,
      waitingForWifi: !canStart,
      errorMessage: canStart ? null : 'Waiting for Wi-Fi',
      phaseLabel: 'Downloading pieces',
      seeders: preview?.seeders ?? 0,
      leechers: preview?.leechers ?? 0,
    );

    _prefetchIds.remove(prefetchId);
    _prefetchLatest.remove(prefetchId);
    final stream = _prefetchStreams.remove(prefetchId);
    unawaited(stream?.close());
    if (_activePrefetchId == prefetchId) {
      _activePrefetchId = null;
      _activePrefetchMagnet = null;
    }

    _items.insert(0, item);
    _emit();

    if (!canStart) return true;

    try {
      await _engine.beginPieceDownload(prefetchId);
      _bootstrapStarted[prefetchId] = DateTime.now();
      _staleRefreshAttempted.remove(prefetchId);
      return true;
    } catch (e, st) {
      AppLog.error('DownloadManager', 'commitPrefetchedDownload failed', e, st);
      _update(
        prefetchId,
        item.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Failed to start download',
        ),
      );
      return false;
    }
  }

  void _onPrefetchProgress(P2pProgressEvent event) {
    final controller = _prefetchStreams[event.id];
    if (controller == null || controller.isClosed) return;

    if (event.isFailed) {
      final failed = MagnetMetadataPreview(
        prefetchId: event.id,
        isValid: false,
        errorMessage: event.errorMessage ?? 'Failed to fetch metadata',
        phaseLabel: event.phaseLabel,
      );
      _prefetchLatest[event.id] = failed;
      controller.add(failed);
      return;
    }

    final preview = MagnetMetadataPreview(
      prefetchId: event.id,
      hasMetadata: event.hasMetadata,
      displayName: event.displayName,
      phaseLabel: event.phaseLabel ?? kDownloadingMetadataLabel,
      seeders: event.numSeeds,
      leechers: event.numPeers,
      isLoading: !event.hasMetadata,
    );
    _prefetchLatest[event.id] = preview;
    controller.add(preview);
  }

  Future<void> importPackageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );
    if (result == null || result.files.single.path == null) return;
    await addTorrentFromSharedPath(
      result.files.single.path!,
      displayName: result.files.single.name,
    );
  }

  Future<void> addTorrentFromSharedPath(
    String path, {
    String? displayName,
  }) async {
    await _ready;

    final id = _uuid.v4();
    final canStart = await _canDownloadNow();
    final item = DownloadItem(
      id: id,
      displayName: displayName ?? path.split('/').last,
      magnetOrHash: path,
      status: canStart ? DownloadStatus.queued : DownloadStatus.paused,
      createdAt: DateTime.now(),
      waitingForWifi: !canStart,
      errorMessage: canStart ? null : 'Waiting for Wi-Fi',
    );
    _items.insert(0, item);
    _emit();

    if (!canStart) return;

    await _resolveAndPrepareDownloadDir();
    await _engine.addTorrentFile(path, id: id);
    _update(id, item.copyWith(status: DownloadStatus.downloading));
  }

  Future<void> pause(String id) async {
    await _engine.pause(id);
    final item = _find(id);
    if (item != null) _update(id, item.copyWith(status: DownloadStatus.paused));
  }

  Future<void> resume(String id) async {
    final item = _find(id);
    if (item == null) return;

    if (!await _canDownloadNow()) {
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.paused,
          waitingForWifi: true,
          errorMessage: 'Waiting for Wi-Fi',
        ),
      );
      return;
    }

    if (_engine.hasHandle(id)) {
      await _engine.resume(id);
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          waitingForWifi: false,
          errorMessage: null,
        ),
      );
      return;
    }

    if (item.status == DownloadStatus.paused && !item.waitingForWifi) {
      await _engine.resume(id);
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          waitingForWifi: false,
          errorMessage: null,
        ),
      );
      return;
    }

    if (item.magnetOrHash.endsWith('.torrent')) {
      await _engine.addTorrentFile(item.magnetOrHash, id: id);
    } else {
      try {
        final resume = await _persistence?.readResume(item.magnetOrHash);
        _metadataGeneration[id] = (_metadataGeneration[id] ?? 0) + 1;
        await _engine.addMagnet(
          item.magnetOrHash,
          id: id,
          resumeData: resume,
        );
      } catch (e, st) {
        AppLog.error('DownloadManager', 'resume addMagnet failed', e, st);
        _update(
          id,
          item.copyWith(
            status: DownloadStatus.failed,
            errorMessage: 'Failed to resume download',
          ),
        );
        return;
      }
    }
    _bootstrapStarted[id] = DateTime.now();
    _staleRefreshAttempted.remove(id);
    _update(
      id,
      item.copyWith(
        status: DownloadStatus.downloading,
        waitingForWifi: false,
        errorMessage: null,
      ),
    );
  }

  Future<void> retryDownload(String id) async {
    await _ready;
    final item = _find(id);
    if (item == null || item.status != DownloadStatus.failed) return;

    AppLog.task('retryDownload', id: id);

    if (_engine.hasHandle(id)) {
      await _engine.remove(id, deleteFiles: false);
    }

    if (!await _canDownloadNow()) {
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.paused,
          waitingForWifi: true,
          errorMessage: 'Waiting for Wi-Fi',
        ),
      );
      return;
    }

    _metadataGeneration[id] = (_metadataGeneration[id] ?? 0) + 1;
    _bootstrapStarted[id] = DateTime.now();
    _metadataReceivedAt.remove(id);
    _staleRefreshAttempted.remove(id);

    try {
      await _resolveAndPrepareDownloadDir();
      if (item.magnetOrHash.endsWith('.torrent')) {
        await _engine.addTorrentFile(item.magnetOrHash, id: id);
      } else {
        final resume = await _persistence?.readResume(item.magnetOrHash);
        await _engine.addMagnet(
          item.magnetOrHash,
          id: id,
          resumeData: resume,
        );
      }
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          progress: 0,
          errorMessage: null,
          phaseLabel: 'Retrying…',
          waitingForWifi: false,
        ),
      );
    } catch (e, st) {
      AppLog.error('DownloadManager', 'retryDownload failed', e, st);
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Failed to retry download',
        ),
      );
    }
  }

  Future<void> cancel(String id) async {
    await _engine.remove(id, deleteFiles: true);
    final item = _find(id);
    if (item != null) {
      _update(id, item.copyWith(status: DownloadStatus.cancelled));
    }
  }

  Future<void> setSpeedLimits({int? downloadKbps, int? uploadKbps}) async {
    await _engine.setSpeedLimits(
      downloadKbps: downloadKbps ?? _settings.downloadLimitKbps,
      uploadKbps: uploadKbps ?? _settings.uploadLimitKbps,
    );
  }

  Future<void> setWifiOnly(bool enabled) async {
    _settings = _settings.copyWith(wifiOnlyDownloads: enabled);
    if (enabled && !await _connectivity.checkIsOnWifi()) {
      await _pauseForWifi();
    } else if (enabled) {
      await _resumeWifiBlocked();
    }
  }

  void updateSettings(AppSettings settings) {
    final prevPath = _settings.downloadDirectoryPath;
    _settings = settings;
    if (prevPath != settings.downloadDirectoryPath) {
      unawaited(_applyDownloadDirectoryFromSettings());
    }
  }

  Future<void> _applyDownloadDirectoryFromSettings() async {
    try {
      await _resolveAndPrepareDownloadDir();
    } catch (e, st) {
      debugPrint('Failed to apply download directory: $e\n$st');
    }
  }

  Future<String> resolveDownloadDirectory() async {
    return _resolveAndPrepareDownloadDir();
  }

  Future<void> setDownloadDirectory(String path) async {
    await _directoryService.ensurePermissions(forPath: path);
    if (!await _directoryService.canWriteTo(path)) {
      throw StateError('Selected folder is not writable');
    }
    await _engine.setDownloadDirectory(path);
  }

  Future<void> resetDownloadDirectory() async {
    final path = await _directoryService.defaultPath();
    if (!await _directoryService.canWriteTo(path)) {
      throw StateError('Default download folder is not writable');
    }
    await _engine.setDownloadDirectory(path);
  }

  Future<void> setTrackerListUrl(String url) async {
    await _trackerManager.setListUrl(url);
    await _trackerManager.refreshFromUrl(url);
    await _engine.applyTrackers(_trackerManager.trackers);
  }

  Future<bool> refreshTrackers({bool force = false}) async {
    final updated = await _trackerManager.maybeAutoRefresh(
      enabled: _settings.autoUpdateTrackersDaily,
      force: force,
    );
    if (updated || force) {
      await _engine.applyTrackers(_trackerManager.trackers);
    }
    return updated;
  }

  Future<void> saveTrackers(List<String> trackers) async {
    await _trackerManager.saveTrackers(trackers);
    await _engine.applyTrackers(_trackerManager.trackers);
  }

  Future<void> savePerDownloadTrackers(String id, List<String> trackers) async {
    await _trackerManager.savePerDownloadTrackers(id, trackers);
    final item = _find(id);
    if (item != null) {
      _update(id, item.copyWith(trackers: trackers));
    }
    await _engine.reannounceAll();
  }

  Future<void> reannounceAll() => _engine.reannounceAll();

  Future<void> _pauseForWifi() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.queued) {
        await _engine.pause(item.id);
        _update(
          item.id,
          item.copyWith(
            status: DownloadStatus.paused,
            waitingForWifi: true,
            errorMessage: 'Waiting for Wi-Fi',
          ),
        );
      }
    }
  }

  Future<void> _resumeWifiBlocked() async {
    for (final item in _items) {
      if (item.waitingForWifi && item.status == DownloadStatus.paused) {
        await resume(item.id);
      }
    }
  }

  void _onEngineProgress(P2pProgressEvent event) {
    try {
      if (_prefetchIds.contains(event.id)) {
        _onPrefetchProgress(event);
        return;
      }

      final item = _find(event.id);
      if (item == null) return;

      if (event.isFailed) {
        _update(
          event.id,
          item.copyWith(
            status: DownloadStatus.failed,
            errorMessage: event.errorMessage ?? 'Download failed',
            phaseLabel: event.phaseLabel,
          ),
        );
        return;
      }

      var status = item.status;
      if (event.isCompleted) {
        status = DownloadStatus.completed;
      } else if (item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.paused) {
        status = DownloadStatus.downloading;
      }

      var updated = item.copyWith(
        status: status,
        progress: event.progress,
        downSpeed: event.downloadBps,
        upSpeed: event.uploadBps,
        seeders: event.numSeeds,
        leechers: event.numPeers,
        displayName: event.displayName ?? item.displayName,
        phaseLabel: event.phaseLabel,
        errorMessage: null,
      );

      if (event.isCompleted) {
        updated = updated.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          completedAt: DateTime.now(),
          savePath: event.savePath,
          waitingForWifi: false,
          phaseLabel: 'Complete',
        );
        if (event.savePath != null) {
          unawaited(_scanner.scanDirectory(event.savePath!).catchError((e, st) {
            debugPrint('Library scan failed: $e\n$st');
            return 0;
          }));
        }
        _bootstrapStarted.remove(event.id);
        _staleRefreshAttempted.remove(event.id);
      } else {
        if (_awaitingPieceDownload.contains(event.id) && event.hasMetadata) {
          _awaitingPieceDownload.remove(event.id);
          _metadataReceivedAt[event.id] = DateTime.now();
          unawaited(_startPieceDownloadAfterMetadata(event.id, updated, event));
        } else if (event.hasMetadata &&
            !_metadataReceivedAt.containsKey(event.id)) {
          _metadataReceivedAt[event.id] = DateTime.now();
        }
        unawaited(_maybeRefreshStaleDownload(event.id, updated, event));
        unawaited(_maybeFailMetadataTimeout(event.id, updated, event));
        unawaited(_maybeFailStallTimeout(event.id, updated, event));
      }

      _update(event.id, updated);
    } catch (e, st) {
      AppLog.error('DownloadManager', 'Progress update failed', e, st);
    }
  }

  Future<void> _startPieceDownloadAfterMetadata(
    String id,
    DownloadItem item,
    P2pProgressEvent event,
  ) async {
    try {
      await _engine.beginPieceDownload(id);
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          displayName: event.displayName ?? item.displayName,
          phaseLabel: 'Downloading pieces',
          seeders: event.numSeeds,
          leechers: event.numPeers,
        ),
      );
    } catch (e, st) {
      AppLog.error('DownloadManager', 'Auto piece download failed', e, st);
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Failed to start download after metadata',
        ),
      );
    }
  }

  Future<void> _maybeFailMetadataTimeout(
    String id,
    DownloadItem item,
    P2pProgressEvent event,
  ) async {
    if (item.status != DownloadStatus.downloading) return;
    if (event.hasMetadata) return;

    final generation = _metadataGeneration[id];
    if (generation == null) return;

    final started = _bootstrapStarted[id];
    if (started == null) return;
    if (DateTime.now().difference(started) < _metadataTimeout) return;
    if (event.numPeers > 0 || event.numSeeds > 0) return;
    if (!event.seedsKnown || !event.peersKnown) return;

    if (_metadataGeneration[id] != generation) return;

    _update(
      id,
      item.copyWith(
        status: DownloadStatus.failed,
        errorMessage:
            'No peers found via DHT or trackers. Check internet and try again.',
        phaseLabel: 'No peers',
      ),
    );
    await _engine.remove(id, deleteFiles: true);
    _bootstrapStarted.remove(id);
    _metadataGeneration.remove(id);
  }

  Future<void> _maybeFailStallTimeout(
    String id,
    DownloadItem item,
    P2pProgressEvent event,
  ) async {
    if (item.status != DownloadStatus.downloading) return;
    if (!event.hasMetadata) return;
    if (item.progress > 0.01 || event.downloadBps > 0) return;
    if (event.numSeeds > 0 && event.downloadBps == 0) {
      // Has seeds but no progress yet — allow more time.
    }

    final metadataAt = _metadataReceivedAt[id];
    if (metadataAt == null) return;
    if (DateTime.now().difference(metadataAt) < _stallTimeout) return;
    if (event.numPeers > 0 || event.numSeeds > 0) {
      if (DateTime.now().difference(metadataAt) < _stallTimeout * 2) return;
    }

    _update(
      id,
      item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: 'Download stalled with no progress. Try again.',
        phaseLabel: 'Stalled',
      ),
    );
    await _engine.remove(id, deleteFiles: false);
    _bootstrapStarted.remove(id);
    _metadataReceivedAt.remove(id);
  }

  Future<void> _maybeRefreshStaleDownload(
    String id,
    DownloadItem item,
    P2pProgressEvent event,
  ) async {
    if (item.status != DownloadStatus.downloading) return;
    if (_engine.isMetadataOnly(id)) {
      if (event.hasMetadata) return;
    }
    if (item.progress > 0.01 || event.numSeeds > 0 || event.numPeers > 0) {
      return;
    }
    if (!event.seedsKnown || !event.peersKnown) return;
    if (_staleRefreshAttempted.contains(id)) return;

    final started = _bootstrapStarted[id];
    if (started == null) return;
    if (DateTime.now().difference(started) < _stalePeerTimeout) return;

    _staleRefreshAttempted.add(id);
    AppLog.task('staleRefresh', id: id);
    await _engine.reannounceTorrent(id);
    _update(
      id,
      item.copyWith(
        phaseLabel: event.hasMetadata
            ? 'Waiting for peers…'
            : 'Searching DHT for peers…',
      ),
    );
  }

  DownloadItem? _find(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  void _update(String id, DownloadItem item) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) _items[index] = item;
    unawaited(_persistence?.sync(item));
    _emit();
  }

  Future<void> shutdownGracefully() async {
    if (_disposed) return;

    for (final item in _items) {
      if (_engine.hasHandle(item.id)) {
        _engine.requestSaveResumeData(item.id);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 750));

    for (final item in _items) {
      await _persistence?.sync(item);
    }
    await _engine.saveSessionState();

    AppLog.sys('DownloadManager shutdownGracefully complete');
  }

  void _pushCurrentItems() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(List.unmodifiable(_items));
  }

  void _emit() => _pushCurrentItems();

  void dispose() {
    _disposed = true;
    _resumeSaveTimer?.cancel();
    _alertSub?.cancel();
    _wifiSub?.cancel();
    _progressSub?.cancel();
    for (final id in _prefetchIds.toList()) {
      unawaited(_engine.remove(id, deleteFiles: true));
    }
    _prefetchIds.clear();
    for (final stream in _prefetchStreams.values) {
      unawaited(stream.close());
    }
    _prefetchStreams.clear();
    _controller.close();
  }
}
