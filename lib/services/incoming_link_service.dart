import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';

/// Handles incoming magnet links, shared text, and .torrent files.
class IncomingLinkService {
  IncomingLinkService(this._ref);

  final Ref _ref;

  Future<void> handleLink(String link) async {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('magnet:')) {
      await _ref.read(downloadManagerProvider).addMagnet(trimmed);
      return;
    }

    if (trimmed.endsWith('.torrent') && trimmed.contains('/')) {
      await _ref
          .read(downloadManagerProvider)
          .addTorrentFromSharedPath(trimmed);
    }
  }

  Future<void> handleSharedText(String? text) async {
    if (text == null) return;
    if (text.startsWith('magnet:')) {
      await handleLink(text);
    }
  }

  Future<void> handleSharedFile(String? path) async {
    if (path == null) return;
    if (path.endsWith('.torrent')) {
      await _ref.read(downloadManagerProvider).addTorrentFromSharedPath(path);
    }
  }
}

final incomingLinkServiceProvider = Provider<IncomingLinkService>((ref) {
  return IncomingLinkService(ref);
});
