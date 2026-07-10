import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/utils/formatters.dart';
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/domain/library/library_view_strategy.dart';
import 'package:torrent_music/features/player/player_provider.dart';
import 'package:torrent_music/shared/widgets/empty_state.dart';

const _libraryViewFactory = LibraryViewStrategyFactory();

enum LibraryView { songs, artists, albums, genres, years }

class LibraryFilter {
  const LibraryFilter({
    this.query = '',
    this.artist,
    this.album,
    this.year,
    this.genre,
    this.format,
  });

  final String query;
  final String? artist;
  final String? album;
  final int? year;
  final String? genre;
  final String? format;

  LibraryFilter copyWith({
    String? query,
    String? artist,
    String? album,
    int? year,
    String? genre,
    String? format,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearYear = false,
    bool clearGenre = false,
    bool clearFormat = false,
  }) {
    return LibraryFilter(
      query: query ?? this.query,
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbum ? null : (album ?? this.album),
      year: clearYear ? null : (year ?? this.year),
      genre: clearGenre ? null : (genre ?? this.genre),
      format: clearFormat ? null : (format ?? this.format),
    );
  }
}

final libraryFilterProvider = StateProvider<LibraryFilter>((ref) {
  return const LibraryFilter();
});

final libraryViewProvider = StateProvider<LibraryView>((ref) {
  return LibraryView.songs;
});

final filteredTracksProvider = FutureProvider<List<Track>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final filter = ref.watch(libraryFilterProvider);

  List<Track> tracks;
  if (filter.query.isNotEmpty) {
    tracks = await repo.search(filter.query);
  } else {
    tracks = await repo.filter(
      artist: filter.artist,
      album: filter.album,
      year: filter.year,
      genre: filter.genre,
      format: filter.format,
    );
  }
  return tracks;
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final view = ref.watch(libraryViewProvider);
    final filter = ref.watch(libraryFilterProvider);
    final tracksAsync = ref.watch(filteredTracksProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            onPressed: () => _scanLibrary(ref),
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan library',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search songs, artists, albums...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(libraryFilterProvider.notifier).state =
                    filter.copyWith(query: value);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: LibraryView.values.map((v) {
                final selected = view == v;
                final strategy = _libraryViewFactory.create(v);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(strategy.label),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(libraryViewProvider.notifier).state = v,
                  ),
                );
              }).toList(),
            ),
          ),
          _FilterChips(filter: filter, ref: ref),
          Expanded(
            child: tracksAsync.when(
              data: (tracks) => _buildBody(context, ref, theme, view, tracks),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppTheme theme,
    LibraryView view,
    List<Track> tracks,
  ) {
    if (tracks.isEmpty) {
      return EmptyState(
        theme: theme,
        icon: Icons.library_music_outlined,
        title: 'No music yet',
        subtitle: 'Download or import tracks to build your library.',
        actionLabel: 'Scan music folder',
        onAction: () => _scanLibrary(ref),
      );
    }

    final strategy = _libraryViewFactory.create(view);
    return switch (view) {
      LibraryView.songs => _SongList(tracks: tracks, ref: ref),
      _ => _GroupedList(
          items: strategy.groupKeys(tracks),
          onTap: (key) {
            ref.read(libraryFilterProvider.notifier).state =
                strategy.filterForSelection(key, ref.read(libraryFilterProvider));
            ref.read(libraryViewProvider.notifier).state = LibraryView.songs;
          },
        ),
    };
  }

  Future<void> _scanLibrary(WidgetRef ref) async {
    final dir = await getApplicationDocumentsDirectory();
    final musicDir = '${dir.path}/Music';
    await ref.read(libraryScannerProvider).scanDirectory(musicDir);
    ref.invalidate(tracksProvider);
    ref.invalidate(filteredTracksProvider);
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter, required this.ref});

  final LibraryFilter filter;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];
    if (filter.artist != null) {
      chips.add(_chip('Artist: ${filter.artist}', () {
        ref.read(libraryFilterProvider.notifier).state =
            filter.copyWith(clearArtist: true);
      }));
    }
    if (filter.album != null) {
      chips.add(_chip('Album: ${filter.album}', () {
        ref.read(libraryFilterProvider.notifier).state =
            filter.copyWith(clearAlbum: true);
      }));
    }
    if (filter.year != null) {
      chips.add(_chip('Year: ${filter.year}', () {
        ref.read(libraryFilterProvider.notifier).state =
            filter.copyWith(clearYear: true);
      }));
    }
    if (filter.genre != null) {
      chips.add(_chip('Genre: ${filter.genre}', () {
        ref.read(libraryFilterProvider.notifier).state =
            filter.copyWith(clearGenre: true);
      }));
    }
    if (chips.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(label: Text(label), onDeleted: onDeleted),
    );
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({required this.tracks, required this.ref});

  final List<Track> tracks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          leading: CircleAvatar(child: Text(initials(track.title))),
          title: Text(track.title),
          subtitle: Text('${track.artist} · ${track.album}'),
          trailing: Text(
            formatDuration(track.duration),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: () async {
            await ref.read(playerProvider.notifier).playTrack(track, queue: tracks);
            if (context.mounted) context.push('/now-playing');
          },
        );
      },
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.chevron_right),
          title: Text(item),
          onTap: () => onTap(item),
        );
      },
    );
  }
}
