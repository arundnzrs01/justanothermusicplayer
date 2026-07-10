import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/app.dart';
import 'package:torrent_music/core/providers/app_settings_provider.dart';
import 'package:torrent_music/core/theme/theme_notifier.dart';
import 'package:torrent_music/services/audio/music_audio_handler.dart';
import 'package:torrent_music/services/share_intent_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(themeProvider.notifier).load();
  await container.read(appSettingsProvider.notifier).load();
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
