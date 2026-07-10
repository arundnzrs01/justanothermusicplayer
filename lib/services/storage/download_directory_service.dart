import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const kDefaultDownloadFolderName = 'JAMP';

final downloadDirectoryServiceProvider = Provider<DownloadDirectoryService>((ref) {
  return DownloadDirectoryService();
});

/// Resolves and manages the user-configurable download folder.
class DownloadDirectoryService {
  /// Paths on shared storage that need MANAGE_EXTERNAL_STORAGE on Android 11+.
  bool isPublicStoragePath(String path) {
    final normalized = path.toLowerCase();
    return normalized.startsWith('/storage/') ||
        normalized.startsWith('/sdcard/') ||
        normalized.contains('/emulated/0/');
  }

  bool isAppScopedPath(String path) {
    return path.contains('/Android/data/') || path.contains('/Android/media/');
  }

  Future<String> defaultPath() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        return '${ext.path}/$kDefaultDownloadFolderName';
      }
      final docs = await getApplicationDocumentsDirectory();
      return '${docs.path}/$kDefaultDownloadFolderName';
    }
    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      return '${docs.path}/$kDefaultDownloadFolderName';
    }
    final home = Platform.environment['HOME'];
    if (home != null) {
      return '$home/$kDefaultDownloadFolderName';
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$kDefaultDownloadFolderName';
  }

  Future<bool> ensurePermissions({String? forPath}) async {
    if (!Platform.isAndroid) return true;

    final target = forPath ?? await defaultPath();
    if (!isPublicStoragePath(target) || isAppScopedPath(target)) {
      return true;
    }

    return _ensurePublicStorageAccess();
  }

  Future<bool> _ensurePublicStorageAccess() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Legacy fallbacks for older Android versions.
    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    return false;
  }

  /// Verifies the directory exists and accepts writes (required before libtorrent).
  Future<bool> canWriteTo(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      final testFile = File('${dir.path}/.jamp_write_test');
      await testFile.writeAsString('ok', flush: true);
      final contents = await testFile.readAsString();
      await testFile.delete();
      return contents == 'ok';
    } catch (e, st) {
      debugPrint('canWriteTo failed for $dirPath: $e\n$st');
      return false;
    }
  }

  /// Picks the first writable directory from configured path and safe fallbacks.
  Future<String> resolvePath(String? configured) async {
    final candidates = <String>[];
    if (configured != null && configured.trim().isNotEmpty) {
      candidates.add(configured.trim());
    }
    candidates.add(await defaultPath());
    final docs = await getApplicationDocumentsDirectory();
    candidates.add('${docs.path}/$kDefaultDownloadFolderName');

    final seen = <String>{};
    for (final path in candidates) {
      if (!seen.add(path)) continue;

      if (isPublicStoragePath(path) && !isAppScopedPath(path)) {
        final allowed = await ensurePermissions(forPath: path);
        if (!allowed) {
          debugPrint('Skipping public path without storage permission: $path');
          continue;
        }
      }

      if (await canWriteTo(path)) {
        if (path != configured) {
          debugPrint('Using writable download path: $path');
        }
        return path;
      }
    }

    throw StateError('No writable download directory available');
  }

  /// True when [resolved] differs from what the user configured (migration needed).
  bool didMigrate(String? configured, String resolved) {
    if (configured == null || configured.trim().isEmpty) return false;
    return configured.trim() != resolved;
  }

  Future<String?> pickDirectory() async {
    if (Platform.isAndroid) {
      await _ensurePublicStorageAccess();
    }

    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (picked == null || picked.isEmpty) return null;

    if (!await canWriteTo(picked)) {
      throw StateError('Selected folder is not writable');
    }
    return picked;
  }
}
