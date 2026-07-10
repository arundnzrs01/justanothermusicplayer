import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/utils/formatters.dart';

class WaveformScrubber extends StatelessWidget {
  const WaveformScrubber({
    super.key,
    required this.waveform,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.theme,
  });

  final List<double> waveform;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) => _seekAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _seekAt(details.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 72),
                  painter: _WaveformPainter(
                    waveform: waveform,
                    progress: progress,
                    theme: theme,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(position),
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
            Text(
              formatDuration(duration),
              style: TextStyle(color: theme.onBackgroundMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  void _seekAt(double dx, double width) {
    if (duration.inMilliseconds == 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    onSeek(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.theme,
  });

  final List<double> waveform;
  final double progress;
  final AppTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barWidth = size.width / waveform.length;
    final playedPaint = Paint()..color = theme.accent;
    final unplayedPaint = Paint()..color = theme.accentMuted.withValues(alpha: 0.4);

    for (var i = 0; i < waveform.length; i++) {
      final x = i * barWidth;
      final barHeight = waveform[i] * size.height;
      final y = (size.height - barHeight) / 2;
      final paint = (i / waveform.length) <= progress ? playedPaint : unplayedPaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, y, barWidth - 2, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.waveform != waveform ||
      oldDelegate.theme != theme;
}
