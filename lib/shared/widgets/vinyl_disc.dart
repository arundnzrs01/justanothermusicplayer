import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';

class VinylDisc extends StatelessWidget {
  const VinylDisc({
    super.key,
    required this.isPlaying,
    required this.theme,
    this.size = 120,
  });

  final bool isPlaying;
  final AppTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isPlaying ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * math.pi * 2,
          child: child,
        );
      },
      child: CustomPaint(
        size: Size(size, size / 2),
        painter: _VinylPainter(theme: theme),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  _VinylPainter({required this.theme});

  final AppTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final outer = Paint()..color = theme.surface;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      true,
      outer,
    );

    final groovePaint = Paint()
      ..color = theme.accentMuted.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var r = radius * 0.55; r < radius * 0.95; r += 6) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi,
        math.pi,
        false,
        groovePaint,
      );
    }

    final accent = Paint()..color = theme.accent;
    canvas.drawCircle(center, radius * 0.18, accent);
    canvas.drawCircle(center, radius * 0.06, Paint()..color = theme.background);
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
