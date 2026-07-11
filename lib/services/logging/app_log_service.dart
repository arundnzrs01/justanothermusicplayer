import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:torrent_music/core/branding/app_branding.dart';

enum LogCategory {
  sys('SYS'),
  nav('NAV'),
  tap('TAP'),
  input('INPUT'),
  task('TASK'),
  p2p('P2P'),
  error('ERROR');

  const LogCategory(this.prefix);
  final String prefix;
}

/// Session audit log — init first in [main] before other startup work.
class AppLog {
  AppLog._();

  static final AppLog _instance = AppLog._();
  static AppLog get I => _instance;

  static const _maxFileBytes = 2 * 1024 * 1024;
  static const _retainedLogs = 10;
  static const _logPrefix = 'jamp_';

  final _linesController = StreamController<String>.broadcast();
  IOSink? _sink;
  File? _logFile;
  Directory? _logsDir;
  int _bytesWritten = 0;
  bool _truncated = false;
  bool _initialized = false;
  DebugPrintCallback? _previousDebugPrint;
  Future<void> _writeChain = Future<void>.value();

  Stream<String> get logLines => _linesController.stream;

  File? get currentLogFile => _logFile;

  static Future<void> init({String? sessionDetail}) async {
    await _instance._init(sessionDetail: sessionDetail);
  }

  static void sys(String message) => _instance._write(LogCategory.sys, message);

  static void nav(String message) => _instance._write(LogCategory.nav, message);

  static void tap(String screen, String action, {String? detail}) {
    final buffer = StringBuffer('screen=$screen action=$action');
    if (detail != null && detail.isNotEmpty) {
      buffer.write(' detail=$detail');
    }
    _instance._write(LogCategory.tap, buffer.toString());
  }

  static void input(String message) => _instance._write(LogCategory.input, message);

  static void task(String name, {String? id, String? phase, String? detail}) {
    final buffer = StringBuffer(name);
    if (id != null && id.isNotEmpty) buffer.write(' id=$id');
    if (phase != null && phase.isNotEmpty) buffer.write(' phase=$phase');
    if (detail != null && detail.isNotEmpty) buffer.write(' detail=$detail');
    _instance._write(LogCategory.task, buffer.toString());
  }

  static void p2p(String event, {String? torrentId, String? detail}) {
    final buffer = StringBuffer(event);
    if (torrentId != null && torrentId.isNotEmpty) {
      buffer.write(' torrent=$torrentId');
    }
    if (detail != null && detail.isNotEmpty) buffer.write(' detail=$detail');
    _instance._write(LogCategory.p2p, buffer.toString());
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer('$tag: $message');
    if (error != null) buffer.write(' error=$error');
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    _instance._write(LogCategory.error, buffer.toString());
  }

  static Future<List<File>> listLogFiles() => _instance._listLogFiles();

  static Future<String> readLogFile(String path) => _instance._readLogFile(path);

  Future<void> _init({String? sessionDetail}) async {
    if (_initialized) return;

    final docs = await getApplicationDocumentsDirectory();
    _logsDir = Directory(p.join(docs.path, 'logs'));
    await _logsDir!.create(recursive: true);

    final stamp = _timestampForFilename(DateTime.now());
    _logFile = File(p.join(_logsDir!.path, '$_logPrefix$stamp.log'));
    _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
    _bytesWritten = 0;
    _truncated = false;
    _initialized = true;

    _installErrorHooks();
    _redirectDebugPrint();

    await _writeLine(
      LogCategory.sys,
      'session start version=${AppBranding.version} platform=${Platform.operatingSystem}',
    );
    if (sessionDetail != null && sessionDetail.isNotEmpty) {
      await _writeLine(LogCategory.sys, sessionDetail);
    }

    unawaited(_pruneOldLogs());
  }

  void _installErrorHooks() {
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      error(
        'FlutterError',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      previousFlutterError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLog.error('PlatformDispatcher', error.toString(), error, stack);
      return true;
    };
  }

  void _redirectDebugPrint() {
    _previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        _write(LogCategory.sys, 'debugPrint: $message');
      }
      _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
    };
  }

  void _write(LogCategory category, String message) {
    if (!_initialized) return;
    _writeChain = _writeChain.then((_) => _writeLine(category, message));
  }

  Future<void> _writeLine(LogCategory category, String message) async {
    if (_sink == null) return;

    final timestamp = DateTime.now().toIso8601String();
    for (final line in message.split('\n')) {
      if (_truncated) return;

      final entry = '$timestamp [${category.prefix}]  $line\n';
      final entryBytes = entry.length;
      if (_bytesWritten + entryBytes > _maxFileBytes) {
        _truncated = true;
        final marker =
            '$timestamp [${LogCategory.sys.prefix}]  log truncated (2 MB cap)\n';
        _sink!.write(marker);
        await _sink!.flush();
        _linesController.add(marker.trimRight());
        return;
      }

      _sink!.write(entry);
      await _sink!.flush();
      _bytesWritten += entryBytes;
      _linesController.add(entry.trimRight());
    }
  }

  Future<List<File>> _listLogFiles() async {
    if (_logsDir == null || !await _logsDir!.exists()) return const [];

    final files = await _logsDir!
        .list()
        .where((entity) =>
            entity is File &&
            p.basename(entity.path).startsWith(_logPrefix) &&
            entity.path.endsWith('.log'))
        .cast<File>()
        .toList();

    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String> _readLogFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> _pruneOldLogs() async {
    final files = await _listLogFiles();
    if (files.length <= _retainedLogs) return;

    for (final file in files.skip(_retainedLogs)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  String _timestampForFilename(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  Future<void> dispose() async {
    if (_initialized) {
      _writeChain =
          _writeChain.then((_) => _writeLine(LogCategory.sys, 'session end'));
      await _writeChain;
    }
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    if (_previousDebugPrint != null) {
      debugPrint = _previousDebugPrint!;
      _previousDebugPrint = null;
    }
    _initialized = false;
  }
}
