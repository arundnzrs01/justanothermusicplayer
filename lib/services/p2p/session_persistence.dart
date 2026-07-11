import 'dart:io';

import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists libtorrent session state (DHT, etc.) under app documents.
class SessionPersistence {
  SessionPersistence({LibtorrentFlutter? engine}) : _engine = engine;

  LibtorrentFlutter? _engine;

  static const _relativeDir = '.jamp';
  static const _fileName = 'session.state';

  void bindEngine(LibtorrentFlutter engine) => _engine = engine;

  static Future<String> sessionStatePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _relativeDir, _fileName);
  }

  static Future<String?> existingSessionStatePath() async {
    final path = await sessionStatePath();
    if (await File(path).exists()) return path;
    return null;
  }

  Future<bool> save() async {
    final engine = _engine;
    if (engine == null) return false;

    final path = await sessionStatePath();
    await Directory(p.dirname(path)).create(recursive: true);
    return engine.saveSessionState(path);
  }

  Future<void> ensureDirectory() async {
    final path = await sessionStatePath();
    await Directory(p.dirname(path)).create(recursive: true);
  }
}
