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
  if (priorities.isEmpty) return;
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
