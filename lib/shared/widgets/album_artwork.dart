import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';
import 'package:torrent_music/core/utils/formatters.dart';

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({
    super.key,
    required this.theme,
    required this.label,
    this.size = 280,
    this.radius = UxRadii.lg,
    this.heroTag,
  });

  final AppTheme theme;
  final String label;
  final double size;
  final double radius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final art = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [theme.accentMuted, theme.accent, theme.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials(label),
        style: TextStyle(
          color: theme.background,
          fontSize: size * 0.17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (heroTag == null) return art;
    return Hero(tag: heroTag!, child: art);
  }
}
