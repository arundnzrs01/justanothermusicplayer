import 'package:flutter/material.dart';
import 'package:torrent_music/core/theme/app_theme.dart';

/// Editable list of tracker / network source URLs.
class TrackerEditorSheet extends StatefulWidget {
  const TrackerEditorSheet({
    super.key,
    required this.title,
    required this.initialTrackers,
    required this.onSave,
    this.listUrl,
    this.onRefreshFromUrl,
  });

  final String title;
  final List<String> initialTrackers;
  final String? listUrl;
  final Future<void> Function(List<String> trackers) onSave;
  final Future<void> Function(String url)? onRefreshFromUrl;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> initialTrackers,
    required Future<void> Function(List<String> trackers) onSave,
    String? listUrl,
    Future<void> Function(String url)? onRefreshFromUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TrackerEditorSheet(
        title: title,
        initialTrackers: initialTrackers,
        onSave: onSave,
        listUrl: listUrl,
        onRefreshFromUrl: onRefreshFromUrl,
      ),
    );
  }

  @override
  State<TrackerEditorSheet> createState() => _TrackerEditorSheetState();
}

class _TrackerEditorSheetState extends State<TrackerEditorSheet> {
  late final List<TextEditingController> _controllers;
  final _urlController = TextEditingController();
  final _newController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllers = widget.initialTrackers
        .map((t) => TextEditingController(text: t))
        .toList();
    _urlController.text = widget.listUrl ?? '';
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _urlController.dispose();
    _newController.dispose();
    super.dispose();
  }

  List<String> _collect() {
    return _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AppTheme>();
    final surface = theme?.surface ?? Theme.of(context).colorScheme.surface;

    return Container(
      color: surface,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.onRefreshFromUrl != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Global source list URL',
                hintText: 'https://example.com/trackers.txt',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final url = _urlController.text.trim();
                  if (url.isEmpty) return;
                  await widget.onRefreshFromUrl!(url);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Fetch from URL'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _controllers.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[index],
                        decoration: InputDecoration(
                          labelText: 'Source ${index + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _controllers[index].dispose();
                          _controllers.removeAt(index);
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newController,
                  decoration: const InputDecoration(
                    labelText: 'Add source URL',
                    hintText: 'udp://tracker.example.com:1337/announce',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final text = _newController.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    _controllers.add(TextEditingController(text: text));
                    _newController.clear();
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await widget.onSave(_collect());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save sources'),
          ),
        ],
      ),
    );
  }
}
