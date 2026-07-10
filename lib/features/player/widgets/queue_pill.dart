import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/data/models/track.dart';

class QueuePill extends StatelessWidget {
  const QueuePill({
    super.key,
    required this.upcoming,
    required this.theme,
    required this.onTap,
  });

  final List<Track> upcoming;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final preview = upcoming
        .take(3)
        .map((t) => t.title)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Queued:',
          style: TextStyle(
            color: theme.onBackgroundMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accentMuted.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.onBackground, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
