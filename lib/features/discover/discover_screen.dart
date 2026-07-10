import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/utils/formatters.dart';
import 'package:torrent_music/data/models/search_result.dart';
import 'package:torrent_music/services/p2p/download_manager.dart';
import 'package:torrent_music/services/search/search_orchestrator.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return [];
  return ref.watch(searchOrchestratorProvider).search(query);
});

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  final _magnetController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(title: const Text('Discover')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLinkSheet(context, theme),
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
              onSubmitted: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
                ref.invalidate(searchResultsProvider);
              },
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (_controller.text.trim().length < 2) {
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
    final magnet = result.magnetUri;
    if (magnet == null) return;
    await ref.read(downloadManagerProvider).addMagnet(
          magnet,
          displayName: result.title,
          sourceName: result.sourceName,
          seeders: result.seeders,
          leechers: result.leechers,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to downloads')),
      );
    }
  }

  void _showAddLinkSheet(BuildContext context, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      builder: (context) => Padding(
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
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final link = _magnetController.text.trim();
                if (link.isEmpty) return;
                await ref.read(downloadManagerProvider).addMagnet(link);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Start download'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(downloadManagerProvider).importPackageFile(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import package file'),
            ),
          ],
        ),
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
          onPressed: onDownload,
          icon: Icon(Icons.download, color: theme.accent),
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
