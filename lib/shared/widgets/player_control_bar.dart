import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    super.key,
    required this.theme,
    required this.isPlaying,
    required this.playMode,
    required this.onTogglePlayPause,
    required this.onSkipPrevious,
    required this.onSkipNext,
    this.onQueue,
    this.onFavorite,
    this.isFavorite = false,
    this.onCyclePlayMode,
  });

  final AppTheme theme;
  final bool isPlaying;
  final PlayMode playMode;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSkipNext;
  final VoidCallback? onQueue;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final VoidCallback? onCyclePlayMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (onQueue != null)
          IconButton(
            onPressed: onQueue,
            icon: Icon(Icons.queue_music, color: theme.onBackground),
          )
        else
          const SizedBox(width: UxTouchTargets.minimum),
        IconButton(
          onPressed: onSkipPrevious,
          icon: Icon(Icons.skip_previous, color: theme.onBackground, size: 32),
        ),
        GestureDetector(
          onTap: onTogglePlayPause,
          child: Container(
            width: UxTouchTargets.playButton,
            height: UxTouchTargets.playButton,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: theme.background,
              size: 36,
            ),
          ),
        ),
        IconButton(
          onPressed: onSkipNext,
          icon: Icon(Icons.skip_next, color: theme.onBackground, size: 32),
        ),
        if (onFavorite != null)
          IconButton(
            onPressed: onFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? theme.favorite : theme.onBackground,
            ),
          )
        else if (onCyclePlayMode != null)
          IconButton(
            onPressed: onCyclePlayMode,
            icon: Icon(playMode.icon, color: theme.accent),
            tooltip: playMode.label,
          )
        else
          const SizedBox(width: UxTouchTargets.minimum),
      ],
    );
  }
}
