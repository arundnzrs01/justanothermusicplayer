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
  Future<String> defaultPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/$kDefaultDownloadFolderName';
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

  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    if (await Permission.manageExternalStorage.isGranted) return true;

    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;

    return storage.isGranted;
  }

  Future<String> resolvePath(String? configured) async {
    await ensurePermissions();
    var path = (configured != null && configured.isNotEmpty)
        ? configured
        : await defaultPath();
    try {
      await _createDir(path);
      return path;
    } catch (_) {
      final ext = await getExternalStorageDirectory();
      final fallback = ext != null
          ? '${ext.path}/$kDefaultDownloadFolderName'
          : '${(await getApplicationDocumentsDirectory()).path}/$kDefaultDownloadFolderName';
      await _createDir(fallback);
      return fallback;
    }
  }

  Future<String?> pickDirectory() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (picked == null || picked.isEmpty) return null;
    await _createDir(picked);
    return picked;
  }

  Future<void> _createDir(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e, st) {
      debugPrint('Failed to create download dir $path: $e\n$st');
      rethrow;
    }
  }
}
