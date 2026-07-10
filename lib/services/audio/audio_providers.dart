import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/services/audio/music_audio_handler.dart';

final audioHandlerProvider = Provider<MusicAudioHandler?>((ref) {
  return MusicAudioHandler.instance;
});
