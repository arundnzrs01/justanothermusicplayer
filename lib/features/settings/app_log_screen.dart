import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';

class AppLogScreen extends ConsumerStatefulWidget {
  const AppLogScreen({super.key});

  @override
  ConsumerState<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends ConsumerState<AppLogScreen> {
  List<File> _logFiles = [];
  String? _selectedPath;
  String _content = '';
  bool _loading = true;
  final Set<LogCategory> _filters = LogCategory.values.toSet();

  @override
  void initState() {
    super.initState();
    unawaited(_loadLogFiles());
  }

  Future<void> _loadLogFiles() async {
    setState(() => _loading = true);
    final files = await AppLog.listLogFiles();
    final current = AppLog.I.currentLogFile?.path;
    var selected = _selectedPath;
    if (selected == null || !files.any((f) => f.path == selected)) {
      selected = current ?? (files.isNotEmpty ? files.first.path : null);
    }
    var content = '';
    if (selected != null) {
      content = await AppLog.readLogFile(selected);
    }
    if (!mounted) return;
    setState(() {
      _logFiles = files;
      _selectedPath = selected;
      _content = content;
      _loading = false;
    });
  }

  String get _filteredContent {
    if (_filters.length == LogCategory.values.length) return _content;
    final lines = _content.split('\n');
    final kept = lines.where((line) {
      for (final category in LogCategory.values) {
        if (!_filters.contains(category)) continue;
        if (line.contains('[${category.prefix}]')) return true;
      }
      return false;
    });
    return kept.join('\n');
  }

  Future<void> _copyToClipboard() async {
    final text = _filteredContent;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copied to clipboard')),
    );
  }

  Future<void> _shareLog() async {
    final text = _filteredContent;
    if (text.isEmpty) return;
    await Share.share(
      text,
      subject: 'JAMP app log',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final display = _filteredContent;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('App logs'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: display.isEmpty ? null : _copyToClipboard,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: display.isEmpty ? null : _shareLog,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadLogFiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_logFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPath,
                      decoration: const InputDecoration(
                        labelText: 'Log file',
                        isDense: true,
                      ),
                      items: _logFiles
                          .map(
                            (file) => DropdownMenuItem(
                              value: file.path,
                              child: Text(
                                p.basename(file.path),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (path) async {
                        if (path == null) return;
                        setState(() => _loading = true);
                        final content = await AppLog.readLogFile(path);
                        if (!mounted) return;
                        setState(() {
                          _selectedPath = path;
                          _content = content;
                          _loading = false;
                        });
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: LogCategory.values.map((category) {
                      final selected = _filters.contains(category);
                      return FilterChip(
                        label: Text(category.prefix),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _filters.add(category);
                            } else if (_filters.length > 1) {
                              _filters.remove(category);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.onBackgroundMuted.withValues(alpha: 0.2),
                        ),
                      ),
                      child: display.isEmpty
                          ? Center(
                              child: Text(
                                'No log entries',
                                style: TextStyle(color: theme.onBackgroundMuted),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                display,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.35,
                                  color: theme.onBackground,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
