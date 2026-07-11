import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/branding/app_branding.dart';
import 'package:torrent_music/core/router/app_router.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';

class JustAnotherMusicPlayerApp extends ConsumerWidget {
  const JustAnotherMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final appTheme = themeState.active;

    return AppLifecycleBridge(
      child: MaterialApp.router(
        title: AppBranding.shortName,
        debugShowCheckedModeBanner: false,
        theme: appTheme.toMaterialTheme(),
        darkTheme: appTheme.toMaterialTheme(),
        themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: appRouter,
      ),
    );
  }
}

/// Persists P2P session state when the app pauses or is detached.
class AppLifecycleBridge extends ConsumerStatefulWidget {
  const AppLifecycleBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleBridge> createState() => _AppLifecycleBridgeState();
}

class _AppLifecycleBridgeState extends ConsumerState<AppLifecycleBridge>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(downloadManagerProvider).shutdownGracefully());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
