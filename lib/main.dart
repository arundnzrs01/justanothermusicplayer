import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/app.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';
import 'package:torrent_music/services/audio/music_audio_handler.dart';
import 'package:torrent_music/services/p2p/tracker_manager.dart';
import 'package:torrent_music/services/share_intent_listener.dart';
import 'package:torrent_music/services/storage/download_directory_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(themeProvider.notifier).load();
  await container.read(appSettingsProvider.notifier).load();
  final settings = container.read(appSettingsProvider);
  final dirService = DownloadDirectoryService();
  try {
    await dirService.ensurePermissions(
      forPath: settings.downloadDirectoryPath,
    );
    await dirService.resolvePath(settings.downloadDirectoryPath);
  } catch (e, st) {
    debugPrint('Startup download path setup failed: $e\n$st');
  }
  final trackerManager = container.read(trackerManagerProvider);
  await trackerManager.load();
  await trackerManager.maybeAutoRefresh(enabled: settings.autoUpdateTrackersDaily);
  await initAudioService();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ShareIntentListener(
        child: JustAnotherMusicPlayerApp(),
      ),
    ),
  );
}
