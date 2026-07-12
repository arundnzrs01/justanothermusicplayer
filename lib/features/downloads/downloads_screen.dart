import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/features/downloads/add_download_sheet.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/logging/log_action.dart';
import 'package:torrent_music/services/torrent/download_manager.dart';
import 'package:torrent_music/shared/widgets/empty_state.dart';

class DownloadsListNotifier extends Notifier<List<DownloadItem>> {
  StreamSubscription<List<DownloadItem>>? _sub;

  @override
  List<DownloadItem> build() {
    final manager = ref.watch(downloadManagerProvider);
    _sub?.cancel();
    state = manager.currentItems;
    _sub = manager.downloads.listen(
      (items) => state = items,
      onError: (e, st) => debugPrint('downloads stream error: $e\n$st'),
    );
    ref.onDispose(() => _sub?.cancel());
    return manager.currentItems;
  }
}

final downloadsProvider =
    NotifierProvider<DownloadsListNotifier, List<DownloadItem>>(
  DownloadsListNotifier.new,
);

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final items = ref.watch(downloadsProvider);
    final manager = ref.watch(downloadManagerProvider);
    final settings = ref.watch(appSettingsProvider);
    final wifiAsync = ref.watch(isOnWifiProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          title: const Text('Downloads'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Failed'),
            ],
          ),
          actions: [
            if (settings.wifiOnlyDownloads)
              wifiAsync.when(
                data: (onWifi) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    onWifi ? Icons.wifi : Icons.wifi_off,
                    color: onWifi ? theme.accent : theme.onBackgroundMuted,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            _DownloadList(
              items: items
                  .where((d) =>
                      d.status == DownloadStatus.downloading ||
                      d.status == DownloadStatus.queued ||
                      d.status == DownloadStatus.paused)
                  .toList(),
              manager: manager,
              emptyTitle: 'No active downloads',
              emptySubtitle: 'Tap + to paste a magnet link or upload a torrent file',
              emptyIcon: Icons.download_outlined,
            ),
            _DownloadList(
              items: items
                  .where((d) => d.status == DownloadStatus.completed)
                  .toList(),
              manager: manager,
              emptyTitle: 'No completed downloads',
              emptySubtitle: 'Finished downloads will appear here',
              emptyIcon: Icons.check_circle_outline,
            ),
            _DownloadList(
              items: items
                  .where((d) => d.status == DownloadStatus.failed)
                  .toList(),
              manager: manager,
              emptyTitle: 'No failed downloads',
              emptySubtitle: 'Downloads that could not finish will appear here',
              emptyIcon: Icons.error_outline,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            logTap('downloads', 'add');
            AddDownloadSheet.show(context);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _DownloadList extends ConsumerWidget {
  const _DownloadList({
    required this.items,
    required this.manager,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final List<DownloadItem> items;
  final DownloadManager manager;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;

    if (items.isEmpty) {
      return EmptyState(
        theme: theme,
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: TextStyle(
                    color: theme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.phaseLabel != null &&
                    item.status == DownloadStatus.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.phaseLabel!,
                      style: TextStyle(color: theme.accent, fontSize: 12),
                    ),
                  ),
                if (item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.errorMessage!,
                      style: TextStyle(color: theme.accentSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: item.progress.clamp(0, 1),
                  color: theme.accent,
                  backgroundColor: theme.accentMuted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(item.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: theme.onBackgroundMuted),
                    ),
                    Text(
                      '${item.seeders} seeds · ${item.leechers} peers',
                      style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    if (item.status == DownloadStatus.downloading)
                      TextButton(
                        onPressed: () {
                          logTap('downloads', 'pause', item.id);
                          manager.pause(item.id);
                        },
                        child: const Text('Pause'),
                      ),
                    if (item.status == DownloadStatus.paused || item.waitingForWifi)
                      TextButton(
                        onPressed: () {
                          logTap('downloads', 'resume', item.id);
                          manager.resume(item.id);
                        },
                        child: Text(
                          item.waitingForWifi ? 'Resume on Wi-Fi' : 'Resume',
                        ),
                      ),
                    if (item.status == DownloadStatus.failed)
                      TextButton(
                        onPressed: () {
                          logTap('downloads', 'retry', item.id);
                          manager.retryDownload(item.id);
                        },
                        child: const Text('Retry'),
                      ),
                    TextButton(
                      onPressed: () {
                        logTap('downloads', 'cancel', item.id);
                        manager.cancel(item.id);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
