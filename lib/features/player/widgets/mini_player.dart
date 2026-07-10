import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';
import 'package:torrent_music/features/player/player_provider.dart';
import 'package:torrent_music/shared/widgets/album_artwork.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/now-playing'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(UxSpacing.sm, 0, UxSpacing.sm, UxSpacing.xs),
        padding: UxInsets.card,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(UxRadii.md),
          border: Border.all(color: theme.accentMuted.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            AlbumArtwork(
              theme: theme,
              label: track.album,
              size: 44,
              radius: UxRadii.sm,
              heroTag: 'album-art-${track.path}',
            ),
            const SizedBox(width: UxSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.onBackgroundMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(playerProvider.notifier).togglePlayPause(),
              icon: Icon(
                player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: theme.accent,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
