import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/data/models/download_item.dart';
import 'package:torrent_music/features/settings/widgets/tracker_editor_sheet.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';
import 'package:torrent_music/services/p2p/tracker_manager.dart';

final downloadsProvider = StreamProvider<List<DownloadItem>>((ref) {
  return ref.watch(downloadManagerProvider).downloads;
});

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final downloadsAsync = ref.watch(downloadsProvider);
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
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'reannounce':
                    await manager.reannounceAll();
                  case 'trackers':
                    await _openGlobalTrackerEditor(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'reannounce', child: Text('Refresh sources')),
                PopupMenuItem(value: 'trackers', child: Text('Edit global sources')),
              ],
            ),
          ],
        ),
        body: downloadsAsync.when(
          data: (items) => TabBarView(
            children: [
              _DownloadList(
                items: items
                    .where((d) =>
                        d.status == DownloadStatus.downloading ||
                        d.status == DownloadStatus.queued ||
                        d.status == DownloadStatus.paused)
                    .toList(),
                manager: manager,
                ref: ref,
              ),
              _DownloadList(
                items: items
                    .where((d) => d.status == DownloadStatus.completed)
                    .toList(),
                manager: manager,
                ref: ref,
              ),
              _DownloadList(
                items: items
                    .where((d) => d.status == DownloadStatus.failed)
                    .toList(),
                manager: manager,
                ref: ref,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Future<void> _openGlobalTrackerEditor(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(trackerManagerProvider);
    await TrackerEditorSheet.show(
      context,
      title: 'Global network sources',
      initialTrackers: manager.trackers,
      listUrl: manager.listUrl,
      onRefreshFromUrl: (url) async {
        await ref.read(downloadManagerProvider).setTrackerListUrl(url);
      },
      onSave: (trackers) async {
        await ref.read(downloadManagerProvider).saveTrackers(trackers);
      },
    );
  }
}

class _DownloadList extends ConsumerWidget {
  const _DownloadList({
    required this.items,
    required this.manager,
    required this.ref,
  });

  final List<DownloadItem> items;
  final DownloadManager manager;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;

    if (items.isEmpty) {
      return Center(
        child: Text('Nothing here yet', style: TextStyle(color: theme.onBackgroundMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
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
                if (item.sourceName != null)
                  Text(
                    item.sourceName!,
                    style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
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
                      '${item.seeders} sources · ${item.leechers} waiting',
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
                        onPressed: () => manager.pause(item.id),
                        child: const Text('Pause'),
                      ),
                    if (item.status == DownloadStatus.paused ||
                        item.waitingForWifi)
                      TextButton(
                        onPressed: () => manager.resume(item.id),
                        child: Text(item.waitingForWifi ? 'Resume on Wi-Fi' : 'Resume'),
                      ),
                    TextButton(
                      onPressed: () => _openPerDownloadTrackers(context, item),
                      child: const Text('Sources'),
                    ),
                    TextButton(
                      onPressed: () => manager.cancel(item.id),
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

  Future<void> _openPerDownloadTrackers(
    BuildContext context,
    DownloadItem item,
  ) async {
    final trackers = item.trackers.isNotEmpty
        ? item.trackers
        : ref.read(trackerManagerProvider).trackers;

    await TrackerEditorSheet.show(
      context,
      title: 'Sources for ${item.displayName}',
      initialTrackers: trackers,
      onSave: (updated) async {
        await ref.read(downloadManagerProvider).savePerDownloadTrackers(
              item.id,
              updated,
            );
      },
    );
  }
}
