import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/providers/app_providers.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';
import 'package:torrent_music/features/player/player_provider.dart';
import 'package:torrent_music/features/player/widgets/queue_pill.dart';
import 'package:torrent_music/features/player/widgets/waveform_scrubber.dart';
import 'package:torrent_music/services/sleep_timer_service.dart';
import 'package:torrent_music/shared/widgets/album_artwork.dart';
import 'package:torrent_music/shared/widgets/empty_state.dart';
import 'package:torrent_music/shared/widgets/player_control_bar.dart';
import 'package:torrent_music/shared/widgets/sleep_timer_picker.dart';
import 'package:torrent_music/shared/widgets/vinyl_disc.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vinylController;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: UxMotion.vinylRotation,
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final player = ref.watch(playerProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final track = player.currentTrack;
    final notifier = ref.read(playerProvider.notifier);

    if (track == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: EmptyState(
          theme: theme,
          icon: Icons.music_off_outlined,
          title: 'Nothing playing',
          subtitle: 'Pick a song from your library to start listening.',
        ),
      );
    }

    if (player.isPlaying) {
      if (!_vinylController.isAnimating) _vinylController.repeat();
    } else {
      _vinylController.stop();
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: UxInsets.screen,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.keyboard_arrow_down, color: theme.onBackground),
                  ),
                  IconButton(
                    onPressed: () => _showMenu(context, theme),
                    icon: Icon(Icons.menu, color: theme.onBackground),
                  ),
                ],
              ),
              const SizedBox(height: UxSpacing.xs),
              AlbumArtwork(
                theme: theme,
                label: track.album,
                heroTag: 'album-art-${track.path}',
              ),
              const SizedBox(height: UxSpacing.xs),
              RotationTransition(
                turns: _vinylController,
                child: VinylDisc(isPlaying: player.isPlaying, theme: theme),
              ),
              const SizedBox(height: UxSpacing.md),
              Text(
                track.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(track.artist, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: UxSpacing.lg),
              PlayerControlBar(
                theme: theme,
                isPlaying: player.isPlaying,
                playMode: player.playMode,
                onTogglePlayPause: notifier.togglePlayPause,
                onSkipPrevious: notifier.skipPrevious,
                onSkipNext: notifier.skipNext,
                onQueue: () => _showQueueSheet(context, theme, player),
                onFavorite: () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .toggleFavorite(track.id, !track.isFavorite);
                  ref.invalidate(tracksProvider);
                },
                isFavorite: track.isFavorite,
              ),
              const SizedBox(height: 20),
              WaveformScrubber(
                waveform: player.waveform,
                position: player.position,
                duration: player.duration,
                onSeek: notifier.seek,
                theme: theme,
              ),
              const SizedBox(height: UxSpacing.lg),
              if (sleepTimer.isActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: UxSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bedtime_outlined, color: theme.accent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Sleep in ${formatSleepRemaining(sleepTimer.remaining!)}',
                        style: TextStyle(color: theme.onBackgroundMuted),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(sleepTimerProvider.notifier).cancel(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              QueuePill(
                upcoming: player.upcomingTracks,
                theme: theme,
                onTap: () => _showQueueSheet(context, theme, player),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, AppTheme theme) {
    final player = ref.read(playerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(player.playMode.icon, color: theme.accent),
              title: Text('Play mode: ${player.playMode.label}',
                  style: TextStyle(color: theme.onBackground)),
              subtitle: const Text('Sequential → Shuffle → Repeat all → Repeat one'),
              onTap: () {
                ref.read(playerProvider.notifier).cyclePlayMode();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.bedtime_outlined, color: theme.accent),
              title: Text('Sleep timer', style: TextStyle(color: theme.onBackground)),
              onTap: () {
                Navigator.pop(context);
                showSleepTimerPicker(
                  context,
                  theme: theme,
                  onSelect: (d) => ref.read(sleepTimerProvider.notifier).start(d),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context, AppTheme theme, PlayerState player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          itemCount: player.queue.length,
          itemBuilder: (context, index) {
            final item = player.queue[index];
            final isCurrent = index == player.currentIndex;
            return ListTile(
              leading: Icon(
                isCurrent ? Icons.equalizer : Icons.music_note,
                color: isCurrent ? theme.accent : theme.onBackgroundMuted,
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  color: isCurrent ? theme.accent : theme.onBackground,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                item.artist,
                style: TextStyle(color: theme.onBackgroundMuted),
              ),
            );
          },
        ),
      ),
    );
  }
}
