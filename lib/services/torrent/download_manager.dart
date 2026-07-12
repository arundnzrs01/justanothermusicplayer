import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/library_scanner.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';
import 'package:torrent_music/services/p2p/magnet_link.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';
import 'package:torrent_music/services/torrent/libretorrent_bridge.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    bridge: LibreTorrentBridge.instance,
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

/// Manages torrent downloads via libtorrent4j (LibreTorrent engine).
class DownloadManager {
  DownloadManager({
    required LibreTorrentBridge bridge,
    required AppDatabase database,
    required LibraryScanner scanner,
    required ConnectivityService connectivity,
    required AppSettings settings,
    required DownloadDirectoryService directoryService,
  })  : _bridge = bridge,
        _database = database,
        _scanner = scanner,
        _connectivity = connectivity,
        _settings = settings,
        _directoryService = directoryService {
    _emit();
    unawaited(_init());
  }

  final LibreTorrentBridge _bridge;
  final AppDatabase _database;
  final LibraryScanner _scanner;
  final ConnectivityService _connectivity;
  AppSettings _settings;
  final DownloadDirectoryService _directoryService;

  final _controller = StreamController<List<DownloadItem>>.broadcast();
  final List<DownloadItem> _items = [];
  StreamSubscription<List<TorrentSnapshot>>? _updatesSub;
  StreamSubscription<bool>? _wifiSub;
  bool _disposed = false;
  String? _downloadDir;

  Stream<List<DownloadItem>> get downloads => _controller.stream;
  List<DownloadItem> get currentItems => List.unmodifiable(_items);
  bool get wifiOnly => _settings.wifiOnlyDownloads;
  String? get downloadDirectory => _downloadDir;

  Future<void> _init() async {
    try {
      _downloadDir = await _resolveDownloadDir();
      await _bridge.initialize(_downloadDir!);
      _bridge.startListening();
      _updatesSub = _bridge.updates.listen(_onSnapshots);
      await _loadFromDb();

      _wifiSub = _connectivity.onWifiChanged.listen((onWifi) {
        if (!_settings.wifiOnlyDownloads) return;
        if (onWifi) {
          unawaited(_resumeWifiBlocked());
        } else {
          unawaited(_pauseForWifi());
        }
      });
    } catch (e, st) {
      AppLog.error('DownloadManager', 'init failed', e, st);
    } finally {
      _emit();
    }
  }

  Future<void> _loadFromDb() async {
    final rows = await _database.getAllDownloads();
    for (final row in rows) {
      _items.add(
        DownloadItem(
          id: row.id,
          displayName: row.displayName,
          magnetOrHash: row.magnetOrHash,
          status: _parseStatus(row.status),
          progress: row.progress,
          downSpeed: row.downSpeed,
          upSpeed: row.upSpeed,
          savePath: row.savePath,
          sourceName: row.sourceName,
          seeders: row.seeders,
          leechers: row.leechers,
          createdAt: row.createdAt,
          completedAt: row.completedAt,
          errorMessage: row.errorMessage,
        ),
      );
    }
  }

  DownloadStatus _parseStatus(String name) {
    return DownloadStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => DownloadStatus.queued,
    );
  }

  Future<String> _resolveDownloadDir() async {
    final configured = _settings.downloadDirectoryPath;
    final dir = await _directoryService.resolvePath(configured);
    if (_directoryService.didMigrate(configured, dir)) {
      _settings = _settings.copyWith(clearDownloadDirectory: true);
      await _database.setSetting('download_directory_path', '');
    }
    return dir;
  }

  Future<bool> _canDownloadNow() async {
    if (!_settings.wifiOnlyDownloads) return true;
    return _connectivity.checkIsOnWifi();
  }

  Future<bool> addMagnet(String magnet) async {
    final parsed = MagnetLink.parse(magnet.trim());
    if (parsed == null) {
      throw ArgumentError('Invalid magnet link');
    }

    if (!await _canDownloadNow()) {
      throw StateError('Waiting for Wi-Fi');
    }

    try {
      _downloadDir ??= await _resolveDownloadDir();
      final id = await _bridge.addMagnet(magnet.trim());
      final item = DownloadItem(
        id: id,
        displayName: parsed.displayName ?? 'Download',
        magnetOrHash: magnet.trim(),
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
        phaseLabel: 'Starting…',
      );
      _upsert(item);
      return true;
    } catch (e, st) {
      AppLog.error('DownloadManager', 'addMagnet failed', e, st);
      return false;
    }
  }

  Future<bool> addTorrentFile(String path) async {
    if (!await _canDownloadNow()) {
      throw StateError('Waiting for Wi-Fi');
    }

    try {
      _downloadDir ??= await _resolveDownloadDir();
      final id = await _bridge.addTorrentFile(path);
      final name = path.split('/').last;
      final item = DownloadItem(
        id: id,
        displayName: name,
        magnetOrHash: path,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
        phaseLabel: 'Starting…',
      );
      _upsert(item);
      return true;
    } catch (e, st) {
      AppLog.error('DownloadManager', 'addTorrentFile failed', e, st);
      return false;
    }
  }

  Future<void> pause(String id) async {
    await _bridge.pause(id);
    final item = _find(id);
    if (item != null) {
      _update(id, item.copyWith(status: DownloadStatus.paused));
    }
  }

  Future<void> resume(String id) async {
    if (!await _canDownloadNow()) {
      final item = _find(id);
      if (item != null) {
        _update(
          id,
          item.copyWith(
            status: DownloadStatus.paused,
            waitingForWifi: true,
            errorMessage: 'Waiting for Wi-Fi',
          ),
        );
      }
      return;
    }
    await _bridge.resume(id);
    final item = _find(id);
    if (item != null) {
      _update(
        id,
        item.copyWith(
          status: DownloadStatus.downloading,
          waitingForWifi: false,
          errorMessage: null,
        ),
      );
    }
  }

  Future<void> retryDownload(String id) async {
    final item = _find(id);
    if (item == null) return;
    if (item.magnetOrHash.startsWith('magnet:')) {
      await addMagnet(item.magnetOrHash);
    } else if (item.magnetOrHash.endsWith('.torrent')) {
      await addTorrentFile(item.magnetOrHash);
    }
  }

  Future<void> cancel(String id) async {
    await _bridge.remove(id, deleteFiles: true);
    final item = _find(id);
    if (item != null) {
      _update(id, item.copyWith(status: DownloadStatus.cancelled));
    }
  }

  Future<void> shutdownGracefully() async {
    await _bridge.shutdown();
  }

  Future<String> resolveDownloadDirectory() => _resolveDownloadDir();

  Future<void> setDownloadDirectory(String path) async {
    await _directoryService.ensurePermissions(forPath: path);
    if (!await _directoryService.canWriteTo(path)) {
      throw StateError('Selected folder is not writable');
    }
    _downloadDir = path;
    await _bridge.initialize(path);
  }

  Future<void> resetDownloadDirectory() async {
    final path = await _directoryService.defaultPath();
    await setDownloadDirectory(path);
  }

  void updateSettings(AppSettings settings) {
    final prevPath = _settings.downloadDirectoryPath;
    _settings = settings;
    if (prevPath != settings.downloadDirectoryPath) {
      unawaited(_resolveDownloadDir().then((dir) async {
        _downloadDir = dir;
        await _bridge.initialize(dir);
      }));
    }
  }

  Future<void> setWifiOnly(bool enabled) async {
    _settings = _settings.copyWith(wifiOnlyDownloads: enabled);
    if (enabled && !await _connectivity.checkIsOnWifi()) {
      await _pauseForWifi();
    } else if (enabled) {
      await _resumeWifiBlocked();
    }
  }

  void _onSnapshots(List<TorrentSnapshot> snapshots) {
    final byId = {for (final s in snapshots) s.id: s};
    for (final snap in snapshots) {
      final existing = _find(snap.id);
      final status = switch (snap.status) {
        'completed' => DownloadStatus.completed,
        'paused' => DownloadStatus.paused,
        'failed' => DownloadStatus.failed,
        _ => DownloadStatus.downloading,
      };

      final item = (existing ??
              DownloadItem(
                id: snap.id,
                displayName: snap.displayName,
                magnetOrHash: snap.id,
                status: status,
                createdAt: DateTime.now(),
              ))
          .copyWith(
        displayName: snap.displayName,
        status: status,
        progress: snap.progress.clamp(0, 1),
        downSpeed: snap.downloadBps,
        upSpeed: snap.uploadBps,
        seeders: snap.seeders,
        leechers: snap.leechers,
        phaseLabel: snap.phaseLabel,
        errorMessage: snap.errorMessage,
        completedAt: status == DownloadStatus.completed ? DateTime.now() : null,
        savePath: status == DownloadStatus.completed ? _downloadDir : null,
      );

      if (existing == null) {
        _items.insert(0, item);
      } else {
        _update(snap.id, item);
      }

      if (status == DownloadStatus.completed && _downloadDir != null) {
        unawaited(_scanner.scanDirectory(_downloadDir!).catchError((_, __) => 0));
      }
    }

    // Drop items no longer in engine (removed externally)
    final activeIds = byId.keys.toSet();
    _items.removeWhere(
      (i) =>
          !activeIds.contains(i.id) &&
          i.status != DownloadStatus.cancelled &&
          i.status != DownloadStatus.completed,
    );
    _emit();
  }

  Future<void> _pauseForWifi() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.downloading) {
        await pause(item.id);
        _update(
          item.id,
          _find(item.id)!.copyWith(
            waitingForWifi: true,
            errorMessage: 'Waiting for Wi-Fi',
          ),
        );
      }
    }
  }

  Future<void> _resumeWifiBlocked() async {
    for (final item in _items) {
      if (item.waitingForWifi) {
        await resume(item.id);
      }
    }
  }

  DownloadItem? _find(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  void _upsert(DownloadItem item) {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.insert(0, item);
    }
    _persist(item);
    _emit();
  }

  void _update(String id, DownloadItem item) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx >= 0) _items[idx] = item;
    _persist(item);
    _emit();
  }

  Future<void> _persist(DownloadItem item) async {
    await _database.upsertDownload(
      DownloadsCompanion(
        id: Value(item.id),
        displayName: Value(item.displayName),
        magnetOrHash: Value(item.magnetOrHash),
        status: Value(item.status.name),
        progress: Value(item.progress),
        downSpeed: Value(item.downSpeed),
        upSpeed: Value(item.upSpeed),
        savePath: Value(item.savePath),
        sourceName: Value(item.sourceName),
        seeders: Value(item.seeders),
        leechers: Value(item.leechers),
        createdAt: item.createdAt == null
            ? const Value.absent()
            : Value(item.createdAt!),
        completedAt: Value(item.completedAt),
        errorMessage: Value(item.errorMessage),
      ),
    );
  }

  void _emit() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(List.unmodifiable(_items));
  }

  void dispose() {
    _disposed = true;
    _updatesSub?.cancel();
    _wifiSub?.cancel();
    unawaited(_controller.close());
  }
}
