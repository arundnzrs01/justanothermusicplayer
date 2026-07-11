import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrent_music/features/discover/discover_screen.dart';
import 'package:torrent_music/features/downloads/downloads_screen.dart';
import 'package:torrent_music/features/library/library_screen.dart';
import 'package:torrent_music/features/player/now_playing_screen.dart';
import 'package:torrent_music/features/settings/app_log_screen.dart';
import 'package:torrent_music/features/settings/settings_screen.dart';
import 'package:torrent_music/services/logging/app_log_navigator_observer.dart';
import 'package:torrent_music/shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/library',
  observers: [AppLogNavigatorObserver()],
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LibraryScreen()),
        ),
        GoRoute(
          path: '/discover',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DiscoverScreen()),
        ),
        GoRoute(
          path: '/downloads',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DownloadsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
          routes: [
            GoRoute(
              path: 'logs',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: AppLogScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/now-playing',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const CustomTransitionPage(
        child: NowPlayingScreen(),
        transitionsBuilder: _slideUpTransition,
      ),
    ),
  ],
);

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
  return SlideTransition(position: offset, child: child);
}
