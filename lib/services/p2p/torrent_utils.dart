import 'package:libtorrent_flutter/libtorrent_flutter.dart';

const _audioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.ogg',
  '.wav',
  '.aac',
  '.opus',
};

bool isAudioFileName(String name) {
  final lower = name.toLowerCase();
  return _audioExtensions.any(lower.endsWith);
}

/// After metadata arrives, skip non-audio files (priority 0).
void prioritizeAudioFiles(LibtorrentFlutter engine, int torrentId) {
  final files = engine.getFiles(torrentId);
  if (files.isEmpty) return;
  final priorities = files.map((f) => isAudioFileName(f.name) ? 7 : 0).toList();
  engine.setFilePriorities(torrentId, priorities);
}

bool isTorrentComplete(TorrentInfo info) {
  return info.isFinished || info.state.isDone || info.progress >= 1.0;
}

String? musicImportPath(TorrentInfo info, List<FileInfo> files) {
  if (info.savePath.isEmpty) return null;
  final audioFiles = files.where((f) => isAudioFileName(f.name)).toList();
  if (audioFiles.isEmpty) return info.savePath;
  return info.savePath;
}

/// Inject a small set of extra tracker URLs into a magnet link.
/// Large tracker lists can overflow native buffers and crash libtorrent.
String injectTrackersIntoMagnet(
  String magnet,
  List<String> trackers, {
  int maxTrackers = 12,
}) {
  if (trackers.isEmpty || !magnet.startsWith('magnet:')) return magnet;

  final seen = <String>{};
  final buffer = StringBuffer(magnet);
  var added = 0;

  for (final tracker in trackers) {
    if (added >= maxTrackers) break;
    final trimmed = tracker.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) continue;
    final encoded = Uri.encodeComponent(trimmed);
    if (magnet.contains(encoded) || magnet.contains(trimmed)) continue;
    seen.add(trimmed);
    buffer.write('&tr=$encoded');
    added++;
  }

  return buffer.toString();
}

bool isValidMagnet(String link) {
  final trimmed = link.trim();
  if (!trimmed.startsWith('magnet:?')) return false;
  return RegExp(r'xt=urn:btih:[0-9a-fA-F]{32,40}', caseSensitive: false)
      .hasMatch(trimmed);
}

String normalizeMagnet(String link) => link.trim();
