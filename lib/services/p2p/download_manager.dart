import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/library_scanner.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/services/p2p/p2p_engine.dart';
import 'package:torrent_music/services/p2p/tracker_manager.dart';
import 'package:torrent_music/services/p2p/torrent_utils.dart';
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
      await _engine.initialize(downloadDir: dir);
      await _trackerManager.load();

      _progressSub = _engine.progressStream.listen(_onEngineProgress);

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
      debugPrint('DownloadManager init error: $e\n$st');
    } finally {
      _emit();
    }

    unawaited(_refreshTrackersInBackground());
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
  }) async {
    await _ready;

    final normalized = normalizeMagnet(magnet);
    if (!isValidMagnet(normalized)) {
      throw ArgumentError('Invalid magnet link');
    }

    final id = _uuid.v4();
    final perDownload = extraTrackers ?? await _trackerManager.getPerDownloadTrackers(id);
    final enhancedMagnet = injectTrackersIntoMagnet(normalized, [
      ..._trackerManager.trackers,
      ...perDownload,
    ]);

    final canStart = await _canDownloadNow();
    final item = DownloadItem(
      id: id,
      displayName: displayName ?? 'Download',
      magnetOrHash: enhancedMagnet,
      status: canStart ? DownloadStatus.queued : DownloadStatus.paused,
      sourceName: sourceName,
      seeders: seeders,
      leechers: leechers,
      createdAt: DateTime.now(),
      trackers: perDownload,
      waitingForWifi: !canStart,
      errorMessage: canStart ? null : 'Waiting for Wi-Fi',
    );
    _items.insert(0, item);
    _emit();

    if (!canStart) return true;

    try {
      await _resolveAndPrepareDownloadDir();
      await _engine.addMagnet(enhancedMagnet, id: id);
      _update(id, item.copyWith(status: DownloadStatus.downloading));
      return true;
    } catch (e, st) {
      debugPrint('addMagnet failed: $e\n$st');
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
        await _engine.addMagnet(item.magnetOrHash, id: id);
      } catch (e, st) {
        debugPrint('resume addMagnet failed: $e\n$st');
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
    _update(
      id,
      item.copyWith(
        status: DownloadStatus.downloading,
        waitingForWifi: false,
        errorMessage: null,
      ),
    );
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
      final item = _find(event.id);
      if (item == null) return;

      var updated = item.copyWith(
        progress: event.progress,
        downSpeed: event.downloadBps,
        upSpeed: event.uploadBps,
        seeders: event.numSeeds,
        leechers: event.numPeers,
        displayName: event.displayName ?? item.displayName,
      );

      if (event.isCompleted) {
        updated = updated.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          completedAt: DateTime.now(),
          savePath: event.savePath,
          waitingForWifi: false,
          errorMessage: null,
        );
        if (event.savePath != null) {
          unawaited(_scanner.scanDirectory(event.savePath!).catchError((e, st) {
            debugPrint('Library scan failed: $e\n$st');
            return 0;
          }));
        }
      }

      _update(event.id, updated);
    } catch (e, st) {
      debugPrint('Progress update failed: $e\n$st');
    }
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
    _emit();
  }

  void _pushCurrentItems() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(List.unmodifiable(_items));
  }

  void _emit() => _pushCurrentItems();

  void dispose() {
    _disposed = true;
    _wifiSub?.cancel();
    _progressSub?.cancel();
    _controller.close();
  }
}
