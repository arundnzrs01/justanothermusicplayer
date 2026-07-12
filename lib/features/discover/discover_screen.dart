import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/utils/formatters.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';
import 'package:torrent_music/services/logging/log_action.dart';
import 'package:torrent_music/services/logging/log_sanitizer.dart';
import 'package:torrent_music/services/p2p/magnet_metadata_preview.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';
import 'package:torrent_music/services/search/scrape_client.dart';
import 'package:torrent_music/services/search/search_orchestrator.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return [];
  return ref.watch(searchOrchestratorProvider).search(query.trim());
});

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  final _scrapeClient = ScrapeClient();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(title: const Text('Discover')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          logTap('discover', 'add_link');
          _showAddLinkSheet(context, theme);
        },
        backgroundColor: theme.accent,
        foregroundColor: theme.background,
        icon: const Icon(Icons.link),
        label: const Text('Add link'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search music across sources...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                ref.read(searchQueryProvider.notifier).state = value.trim();
              },
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (query.trim().length < 2) {
                  return _EmptyDiscover(theme: theme);
                }
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: theme.onBackgroundMuted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _SearchResultTile(
                    result: results[index],
                    theme: theme,
                    onDownload: () => _startDownload(results[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Search failed: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(SearchResult result) async {
    logTap('discover', 'download', result.title);
    var magnet = result.effectiveMagnet;
    if (magnet == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolving download link...')),
      );
      magnet = await _scrapeClient.resolveMagnetForResult(result);
    }
    if (magnet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download link available for this result')),
        );
      }
      return;
    }

    try {
      final addResult = await ref.read(downloadManagerProvider).addMagnet(
            magnet,
            displayName: result.title,
            sourceName: result.sourceName,
            seeders: result.seeders,
            leechers: result.leechers,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !addResult.ok
                  ? 'Failed to start download'
                  : addResult.continuingExisting
                      ? 'Continuing existing download'
                      : 'Added to downloads — fetching metadata',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ArgumentError
            ? (e.message?.toString() ?? 'Invalid magnet link')
            : 'Failed to start download';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _showAddLinkSheet(BuildContext context, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      builder: (context) => _AddLinkSheet(
        theme: theme,
        onCommitted: () {
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _AddLinkSheet extends ConsumerStatefulWidget {
  const _AddLinkSheet({
    required this.theme,
    required this.onCommitted,
  });

  final AppTheme theme;
  final VoidCallback onCommitted;

  @override
  ConsumerState<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends ConsumerState<_AddLinkSheet> {
  final _magnetController = TextEditingController();
  StreamSubscription<MagnetMetadataPreview>? _prefetchSub;
  Timer? _debounce;
  MagnetMetadataPreview? _preview;
  String? _prefetchId;
  late final DownloadManager _downloads;

  @override
  void initState() {
    super.initState();
    _downloads = ref.read(downloadManagerProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _prefetchSub?.cancel();
    if (_prefetchId != null && _preview?.continuingExisting != true) {
      unawaited(_downloads.cancelMetadataPrefetch(_prefetchId!));
    }
    _magnetController.dispose();
    super.dispose();
  }

  void _onMagnetChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        AppLog.input(sanitizeMagnetPaste(trimmed));
      }
      _restartPrefetch(trimmed);
    });
  }

  Future<void> _restartPrefetch(String magnet) async {
    await _prefetchSub?.cancel();
    _prefetchSub = null;
    if (_prefetchId != null) {
      await _downloads.cancelMetadataPrefetch(_prefetchId!);
      _prefetchId = null;
    }

    if (magnet.isEmpty) {
      setState(() => _preview = null);
      return;
    }

    final stream = _downloads.prefetchMetadata(magnet);
    _prefetchSub = stream.listen((preview) {
      if (!mounted) return;
      setState(() {
        _preview = preview;
        if (preview.prefetchId.isNotEmpty) {
          _prefetchId = preview.prefetchId;
        }
      });
    });
  }

  Future<void> _startDownload() async {
    logTap('discover', 'commit_prefetch', _prefetchId);
    final prefetchId = _prefetchId;
    if (prefetchId == null || _preview?.canStartDownload != true) return;

    final ok = await _downloads.commitPrefetchedDownload(
          prefetchId,
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start download')),
      );
      return;
    }

    _prefetchId = null;
    _magnetController.clear();
    setState(() => _preview = null);
    widget.onCommitted();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to downloads')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final preview = _preview;
    final canStart = preview?.canStartDownload == true;

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
          Text('Add link', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _magnetController,
            decoration: const InputDecoration(
              hintText: 'Paste magnet or package link',
            ),
            maxLines: 3,
            onChanged: _onMagnetChanged,
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            if (preview.errorMessage != null)
              Text(
                preview.errorMessage!,
                style: TextStyle(color: theme.accentSecondary, fontSize: 13),
              )
            else ...[
              if (preview.displayName != null)
                Text(
                  preview.displayName!,
                  style: TextStyle(
                    color: theme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (preview.isLoading && !preview.hasMetadata)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accent,
                      ),
                    ),
                  if (preview.isLoading && !preview.hasMetadata)
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.hasMetadata
                          ? 'Metadata ready'
                          : (preview.phaseLabel ?? kDownloadingMetadataLabel),
                      style: TextStyle(color: theme.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canStart ? _startDownload : null,
            child: Text(
              canStart ? 'Start download' : 'Waiting for metadata…',
            ),
          ),
          if (preview != null && !canStart && preview.isValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Metadata must finish before downloading.',
                style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              logTap('discover', 'import_package');
              ref.read(downloadManagerProvider).importPackageFile();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Import package file'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_outlined, size: 64, color: theme.onBackgroundMuted),
          const SizedBox(height: 12),
          Text(
            'Search for music or add a link',
            style: TextStyle(color: theme.onBackgroundMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Sources: TPB, 1337x, Galaxy, Lime, Torlock',
            style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.theme,
    required this.onDownload,
  });

  final SearchResult result;
  final AppTheme theme;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _Badge(label: result.sourceName, color: theme.accent),
                if (result.quality != null)
                  _Badge(label: result.quality!, color: theme.accentSecondary),
                if (!result.canDownload)
                  _Badge(label: 'No link', color: theme.onBackgroundMuted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatBytes(result.sizeBytes)} · ${result.seeders} sources · ${result.leechers} waiting',
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: result.canDownload ? onDownload : null,
          icon: Icon(
            Icons.download,
            color: result.canDownload ? theme.accent : theme.onBackgroundMuted,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
