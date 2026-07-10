import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/core/ux/ux_tokens.dart';

void showSleepTimerPicker(
  BuildContext context, {
  required AppTheme theme,
  required void Function(Duration duration) onSelect,
  List<int> options = const [15, 30, 45, 60, 90],
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.surface,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(UxSpacing.md),
            child: Text('Sleep timer', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...options.map(
            (min) => ListTile(
              title: Text('$min minutes'),
              onTap: () {
                onSelect(Duration(minutes: min));
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String formatSleepRemaining(Duration d) {
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}
