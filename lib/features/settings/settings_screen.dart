import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/branding/app_branding.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';
import 'package:torrent_music/core/theme/theme_presets.dart';
import 'package:torrent_music/features/settings/widgets/tracker_editor_sheet.dart';
import 'package:torrent_music/services/connectivity_service.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';
import 'package:torrent_music/services/p2p/tracker_list_config.dart';
import 'package:torrent_music/services/p2p/tracker_manager.dart';
import 'package:torrent_music/services/search/search_orchestrator.dart';
import 'package:torrent_music/services/sleep_timer_service.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';
import 'package:torrent_music/shared/widgets/section_header.dart';
import 'package:torrent_music/shared/widgets/sleep_timer_picker.dart';
import 'package:uuid/uuid.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _downloadLimitController = TextEditingController();
  final _uploadLimitController = TextEditingController();
  final _indexerUrlController = TextEditingController();
  final _indexerKeyController = TextEditingController();
  final _indexerNameController = TextEditingController();

  @override
  void dispose() {
    _downloadLimitController.dispose();
    _uploadLimitController.dispose();
    _indexerUrlController.dispose();
    _indexerKeyController.dispose();
    _indexerNameController.dispose();
    super.dispose();
  }

  void _syncIndexerFields(IndexerConfig indexer) {
    _indexerUrlController.text = indexer.baseUrl;
    _indexerKeyController.text = indexer.apiKey;
    _indexerNameController.text = indexer.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final themeState = ref.watch(themeProvider);
    final settings = ref.watch(appSettingsProvider);
    final wifiAsync = ref.watch(isOnWifiProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    if (_downloadLimitController.text.isEmpty && settings.downloadLimitKbps > 0) {
      _downloadLimitController.text = '${settings.downloadLimitKbps}';
    }
    if (_uploadLimitController.text.isEmpty && settings.uploadLimitKbps > 0) {
      _uploadLimitController.text = '${settings.uploadLimitKbps}';
    }
    _syncIndexerFields(settings.indexer);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SectionHeader(title: 'Appearance', theme: theme),
          ...themeState.allThemes.map((preset) {
            final selected = themeState.active.id == preset.id;
            return ListTile(
              leading: _ThemeSwatch(appTheme: preset),
              title: Text(preset.name),
              trailing: selected ? Icon(Icons.check_circle, color: theme.accent) : null,
              onTap: () => ref.read(themeProvider.notifier).setActive(preset.id),
            );
          }),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: theme.accent),
            title: const Text('Create custom theme'),
            onTap: () => _openThemeBuilder(context),
          ),
          const Divider(),
          SectionHeader(title: 'Network', theme: theme),
          SwitchListTile(
            title: const Text('Wi-Fi only downloads'),
            subtitle: wifiAsync.when(
              data: (onWifi) => Text(
                onWifi ? 'Connected via Wi-Fi' : 'On mobile data — downloads paused',
                style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
              ),
              loading: () => null,
              error: (_, __) => null,
            ),
            value: settings.wifiOnlyDownloads,
            onChanged: (value) async {
              await ref.read(appSettingsProvider.notifier).setWifiOnly(value);
              ref.read(downloadManagerProvider).setWifiOnly(value);
              ref.read(downloadManagerProvider).updateSettings(
                    ref.read(appSettingsProvider),
                  );
            },
          ),
          ListTile(
            leading: Icon(Icons.dns_outlined, color: theme.accent),
            title: const Text('Edit network sources'),
            subtitle: Text(
              '${ref.read(trackerManagerProvider).trackers.length} trackers · ${TrackerListConfig.sourceName}',
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
            onTap: () => _openTrackerEditor(context),
          ),
          SwitchListTile(
            title: const Text('Auto-update trackers daily'),
            subtitle: Text(
              'Fetch ${TrackerListConfig.listFile} from ${TrackerListConfig.sourceName}',
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
            value: settings.autoUpdateTrackersDaily,
            onChanged: (value) async {
              await ref
                  .read(appSettingsProvider.notifier)
                  .setAutoUpdateTrackersDaily(value);
              ref.read(downloadManagerProvider).updateSettings(
                    ref.read(appSettingsProvider),
                  );
              if (value) {
                final ok = await ref
                    .read(downloadManagerProvider)
                    .refreshTrackers(force: true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Trackers updated' : 'Could not refresh trackers',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.update, color: theme.accent),
            title: const Text('Refresh trackers now'),
            subtitle: Text(
              _formatTrackerUpdated(
                ref.read(downloadManagerProvider).trackersLastUpdated,
              ),
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
            onTap: () async {
              final ok =
                  await ref.read(downloadManagerProvider).refreshTrackers(force: true);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Trackers updated' : 'Refresh failed — check connection',
                  ),
                ),
              );
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _downloadLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Download limit (KB/s)',
                      hintText: '0 = unlimited',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _uploadLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Upload limit (KB/s)',
                      hintText: '0 = unlimited',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                final down = int.tryParse(_downloadLimitController.text) ?? 0;
                final up = int.tryParse(_uploadLimitController.text) ?? 0;
                await ref.read(appSettingsProvider.notifier).setSpeedLimits(
                      downloadKbps: down,
                      uploadKbps: up,
                    );
                await ref.read(downloadManagerProvider).setSpeedLimits(
                      downloadKbps: down,
                      uploadKbps: up,
                    );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Speed limits updated')),
                );
              },
              child: const Text('Apply speed limits'),
            ),
          ),
          const Divider(),
          SectionHeader(title: 'Storage', theme: theme),
          FutureBuilder<String>(
            future: ref.read(downloadDirectoryServiceProvider).resolvePath(
                  settings.downloadDirectoryPath,
                ),
            builder: (context, snapshot) {
              final path = snapshot.data ?? settings.downloadDirectoryPath ?? '…';
              return ListTile(
                leading: Icon(Icons.folder_outlined, color: theme.accent),
                title: const Text('Download folder'),
                subtitle: Text(
                  path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
                ),
                onTap: () => _pickDownloadFolder(context),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.restore, color: theme.accent),
            title: const Text('Reset download folder'),
            subtitle: const Text('App folder (no extra permissions needed)'),
            onTap: () => _resetDownloadFolder(context),
          ),
          const Divider(),
          SectionHeader(title: 'Discover', theme: theme),
          SwitchListTile(
            title: const Text('Custom indexer (Jackett)'),
            subtitle: Text(
              settings.indexer.isConfigured
                  ? settings.indexer.displayName
                  : 'Add base URL and API key',
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
            value: settings.indexer.enabled,
            onChanged: settings.indexer.isConfigured
                ? (v) async {
                    await ref.read(appSettingsProvider.notifier).setIndexer(
                          settings.indexer.copyWith(enabled: v),
                        );
                    ref.invalidate(searchOrchestratorProvider);
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _indexerNameController,
              decoration: const InputDecoration(labelText: 'Indexer display name'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _indexerUrlController,
              decoration: const InputDecoration(
                labelText: 'Indexer base URL',
                hintText: 'http://192.168.1.10:9117',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _indexerKeyController,
              decoration: const InputDecoration(labelText: 'API key'),
              obscureText: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                final config = IndexerConfig(
                  enabled: true,
                  baseUrl: _indexerUrlController.text.trim(),
                  apiKey: _indexerKeyController.text.trim(),
                  displayName: _indexerNameController.text.trim().isEmpty
                      ? 'Custom Indexer'
                      : _indexerNameController.text.trim(),
                );
                await ref.read(appSettingsProvider.notifier).setIndexer(config);
                ref.invalidate(searchOrchestratorProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Indexer saved')),
                );
              },
              child: const Text('Save indexer'),
            ),
          ),
          const Divider(),
          SectionHeader(title: 'Playback', theme: theme),
          if (sleepTimer.isActive)
            ListTile(
              leading: Icon(Icons.timer, color: theme.accent),
              title: Text('Sleep timer: ${formatSleepRemaining(sleepTimer.remaining!)}'),
              trailing: TextButton(
                onPressed: () => ref.read(sleepTimerProvider.notifier).cancel(),
                child: const Text('Cancel'),
              ),
            ),
          ListTile(
            leading: Icon(Icons.bedtime_outlined, color: theme.accent),
            title: const Text('Sleep timer'),
            subtitle: const Text('Stop playback after a set time'),
            onTap: () => showSleepTimerPicker(
              context,
              theme: theme,
              onSelect: (d) => ref.read(sleepTimerProvider.notifier).start(d),
            ),
          ),
          const Divider(),
          SectionHeader(title: 'About', theme: theme),
          ListTile(
            title: Text(AppBranding.shortName),
            subtitle: Text('${AppBranding.fullName} v${AppBranding.version}'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDownloadFolder(BuildContext context) async {
    final service = ref.read(downloadDirectoryServiceProvider);
    try {
      await service.ensurePermissions();
      final picked = await service.pickDirectory();
      if (picked == null) return;
      await ref.read(appSettingsProvider.notifier).setDownloadDirectory(picked);
      await ref.read(downloadManagerProvider).setDownloadDirectory(picked);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloads will save to $picked')),
      );
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not use that folder — check storage permission')),
      );
    }
  }

  Future<void> _resetDownloadFolder(BuildContext context) async {
    final service = ref.read(downloadDirectoryServiceProvider);
    try {
      await service.ensurePermissions();
      final path = await service.defaultPath();
      await ref.read(appSettingsProvider.notifier).setDownloadDirectory(path);
      await ref.read(downloadManagerProvider).setDownloadDirectory(path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset to $path')),
      );
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset download folder')),
      );
    }
  }

  Future<void> _openTrackerEditor(BuildContext context) async {
    final manager = ref.read(trackerManagerProvider);
    await TrackerEditorSheet.show(
      context,
      title: 'Global network sources',
      initialTrackers: manager.trackers,
      listUrl: manager.listUrl.isNotEmpty
          ? manager.listUrl
          : TrackerListConfig.defaultListUrl,
      onRefreshFromUrl: (url) async {
        await ref.read(downloadManagerProvider).setTrackerListUrl(url);
      },
      onSave: (trackers) async {
        await ref.read(downloadManagerProvider).saveTrackers(trackers);
      },
    );
  }

  String _formatTrackerUpdated(DateTime? updated) {
    if (updated == null) return 'Never updated';
    final local = updated.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return 'Last updated $date $time';
  }

  Future<void> _openThemeBuilder(BuildContext context) async {
    var draft = ThemePresets.pastelMeadow.copyWith(
      id: 'custom_${const Uuid().v4()}',
      name: 'My Theme',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: draft.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Custom theme', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _ColorRow(
                  label: 'Background',
                  color: draft.background,
                  onPick: (c) => setModalState(() => draft = draft.copyWith(background: c)),
                ),
                _ColorRow(
                  label: 'Surface',
                  color: draft.surface,
                  onPick: (c) => setModalState(() => draft = draft.copyWith(surface: c)),
                ),
                _ColorRow(
                  label: 'Accent',
                  color: draft.accent,
                  onPick: (c) => setModalState(() => draft = draft.copyWith(accent: c)),
                ),
                _ColorRow(
                  label: 'Text',
                  color: draft.onBackground,
                  onPick: (c) =>
                      setModalState(() => draft = draft.copyWith(onBackground: c)),
                ),
                const SizedBox(height: 12),
                _ThemePreview(appTheme: draft),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await ref.read(themeProvider.notifier).saveCustomTheme(draft);
                    await ref.read(themeProvider.notifier).setActive(draft.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save and apply'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.appTheme});

  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(appTheme.background),
        _dot(appTheme.accent),
        _dot(appTheme.onBackground),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onPick,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: GestureDetector(
        onTap: () async {
          final picked = await showColorPickerDialog(
            context,
            color,
            pickersEnabled: const {
              ColorPickerType.wheel: true,
              ColorPickerType.accent: false,
            },
          );
          onPick(picked);
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.appTheme});

  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: appTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          Text('Song Title', style: TextStyle(color: appTheme.onBackground)),
          Text('Artist', style: TextStyle(color: appTheme.onBackgroundMuted)),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: appTheme.accent, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow, color: appTheme.background),
          ),
        ],
      ),
    );
  }
}
