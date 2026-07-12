import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/core/theme/app_theme.dart';
import 'package:torrent_music/services/torrent/download_manager.dart';

/// Bottom sheet: paste a magnet link or pick a .torrent file.
class AddDownloadSheet extends ConsumerStatefulWidget {
  const AddDownloadSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const AddDownloadSheet(),
      ),
    );
  }

  @override
  ConsumerState<AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends ConsumerState<AddDownloadSheet> {
  final _magnetController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _magnetController.dispose();
    super.dispose();
  }

  Future<void> _addMagnet() async {
    final magnet = _magnetController.text.trim();
    if (magnet.isEmpty) return;

    setState(() => _busy = true);
    try {
      final ok = await ref.read(downloadManagerProvider).addMagnet(magnet);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download added')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add download')),
        );
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Invalid magnet')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTorrentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(downloadManagerProvider)
          .addTorrentFile(result.files.single.path!);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download added')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add download')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add download',
            style: TextStyle(
              color: theme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _magnetController,
            decoration: const InputDecoration(
              labelText: 'Magnet link',
              hintText: 'magnet:?xt=urn:btih:…',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _addMagnet,
            child: const Text('Start download'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickTorrentFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload .torrent file'),
          ),
        ],
      ),
    );
  }
}
