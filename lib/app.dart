import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/branding/app_branding.dart';
import 'package:torrent_music/core/router/app_router.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';

class JustAnotherMusicPlayerApp extends ConsumerWidget {
  const JustAnotherMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final appTheme = themeState.active;

    return MaterialApp.router(
      title: AppBranding.shortName,
      debugShowCheckedModeBanner: false,
      theme: appTheme.toMaterialTheme(),
      darkTheme: appTheme.toMaterialTheme(),
      themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
