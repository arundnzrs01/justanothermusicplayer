import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/branding/app_branding.dart';
import 'package:torrent_music/core/router/app_router.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';
import 'package:torrent_music/features/onboarding/permissions_screen.dart';
import 'package:torrent_music/services/torrent/download_manager.dart';

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

/// Persists torrent session state when the app pauses or is detached.
class AppLifecycleBridge extends ConsumerStatefulWidget {
  const AppLifecycleBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleBridge> createState() => _AppLifecycleBridgeState();
}

class _AppLifecycleBridgeState extends ConsumerState<AppLifecycleBridge>
    with WidgetsBindingObserver {
  bool? _permissionsReady;
  bool _checkingPermissions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkPermissions());
  }

  Future<void> _checkPermissions() async {
    final done = await StartupPermissions.isComplete();
    if (mounted) {
      setState(() {
        _permissionsReady = done;
        _checkingPermissions = false;
      });
    }
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
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_permissionsReady != true) {
      return MaterialApp(
        home: PermissionsOnboardingScreen(
          onComplete: () => setState(() => _permissionsReady = true),
        ),
      );
    }

    return widget.child;
  }
}
