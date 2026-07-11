import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:torrent_music/data/db/app_database.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/services/p2p/magnet_link.dart';

/// Syncs [DownloadItem] rows to Drift and manages per-torrent resume files.
class DownloadPersistence {
  DownloadPersistence({
    required AppDatabase database,
    required String downloadDir,
  })  : _database = database,
        _downloadDir = downloadDir;

  final AppDatabase _database;
  final String _downloadDir;

  String get resumeDir => '$_downloadDir/.jamp/resume';

  Future<void> sync(DownloadItem item) async {
    await _database.upsertDownload(_toCompanion(item));
  }

  Future<List<DownloadItem>> loadAll() async {
    final rows = await _database.getAllDownloads();
    return rows.map(_fromRow).toList();
  }

  Future<void> delete(String id) async {
    await (_database.delete(_database.downloads)..where((d) => d.id.equals(id)))
        .go();
  }

  String? infoHashFor(String magnetOrHash) {
    if (magnetOrHash.endsWith('.torrent')) return null;
    return MagnetLink.parse(magnetOrHash)?.infoHashHex;
  }

  String resumePathForInfoHash(String infoHashHex) {
    return '$resumeDir/$infoHashHex.resume';
  }

  String? resumePathFor(String magnetOrHash) {
    final hash = infoHashFor(magnetOrHash);
    if (hash == null) return null;
    return resumePathForInfoHash(hash);
  }

  Future<Uint8List?> readResume(String magnetOrHash) async {
    final path = resumePathFor(magnetOrHash);
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> writeResume(String magnetOrHash, Uint8List data) async {
    final path = resumePathFor(magnetOrHash);
    if (path == null || data.isEmpty) return;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
  }

  Future<void> writeResumeForInfoHash(String infoHashHex, Uint8List data) async {
    if (data.isEmpty) return;
    final file = File(resumePathForInfoHash(infoHashHex));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
  }

  Future<void> deleteResume(String magnetOrHash) async {
    final path = resumePathFor(magnetOrHash);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  DownloadsCompanion _toCompanion(DownloadItem item) {
    return DownloadsCompanion(
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
    );
  }

  DownloadItem _fromRow(Download row) {
    return DownloadItem(
      id: row.id,
      displayName: row.displayName,
      magnetOrHash: row.magnetOrHash,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => DownloadStatus.queued,
      ),
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
    );
  }
}
