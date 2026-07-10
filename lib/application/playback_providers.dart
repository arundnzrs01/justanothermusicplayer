import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/application/music_player_facade.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';
import 'package:torrent_music/services/audio/audio_providers.dart';
import 'package:torrent_music/services/audio/just_audio_playback_adapter.dart';

final playbackPortProvider = Provider<PlaybackPort>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  if (handler == null) {
    throw StateError('AudioService not initialized');
  }
  return JustAudioPlaybackAdapter(handler);
});

/// Singleton facade — one orchestration surface for the whole app.
final musicPlayerFacadeProvider = Provider<MusicPlayerFacade>((ref) {
  final facade = MusicPlayerFacade(playback: ref.watch(playbackPortProvider));
  ref.onDispose(facade.dispose);
  return facade;
});

/// Decouples services from feature-layer player state.
final playbackPauseProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(musicPlayerFacadeProvider).pause();
});
