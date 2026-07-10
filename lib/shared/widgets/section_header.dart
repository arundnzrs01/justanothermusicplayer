import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.theme,
  });

  final String title;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UxSpacing.md,
        UxSpacing.md,
        UxSpacing.md,
        UxSpacing.xs,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: theme.onBackgroundMuted,
          fontSize: UxTypography.caption,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
