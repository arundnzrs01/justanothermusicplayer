import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:torrent_music/services/incoming_link_service.dart';

/// Listens for shared magnets, links, and torrent files from other apps.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;
  StreamSubscription<Uri>? _linkSub;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initListeners();
  }

  var _initialized = false;

  Future<void> _initListeners() async {
    if (_initialized) return;
    _initialized = true;

    final service = ref.read(incomingLinkServiceProvider);

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) async {
        for (final file in files) {
          if (file.path.endsWith('.torrent')) {
            await service.handleSharedFile(file.path);
          } else if (file.path.startsWith('magnet:')) {
            await service.handleLink(file.path);
          }
        }
      },
    );

    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    for (final file in initialMedia) {
      if (file.path.endsWith('.torrent')) {
        await service.handleSharedFile(file.path);
      } else if (file.path.startsWith('magnet:')) {
        await service.handleLink(file.path);
      }
    }
    await ReceiveSharingIntent.instance.reset();

    _linkSub = _appLinks.uriLinkStream.listen((uri) async {
      final link = uri.toString();
      if (link.startsWith('magnet:')) {
        await service.handleLink(link);
      }
    });

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null && initialUri.toString().startsWith('magnet:')) {
      await service.handleLink(initialUri.toString());
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
