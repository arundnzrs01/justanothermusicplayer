import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/features/player/widgets/mini_player.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return switch (location) {
      '/discover' => 1,
      '/downloads' => 2,
      '/settings' => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final selected = _selectedIndex(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          final path = switch (index) {
            1 => '/discover',
            2 => '/downloads',
            3 => '/settings',
            _ => '/library',
          };
          context.go(path);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        backgroundColor: theme.surface,
      ),
    );
  }
}
