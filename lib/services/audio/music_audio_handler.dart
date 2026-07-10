import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/core/branding/app_branding.dart';

class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MusicAudioHandler() {
    _init();
  }

  static MusicAudioHandler? _instance;
  static MusicAudioHandler? get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<Track> _tracks = [];

  AudioPlayer get player => _player;

  Future<void> _init() async {
    _instance = this;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen(_broadcastState);
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _tracks.length) {
        mediaItem.add(_trackToMediaItem(_tracks[index]));
      }
    });
  }

  Future<void> setTrackQueue(List<Track> tracks, {int startIndex = 0}) async {
    _tracks = List.of(tracks);
    if (tracks.isEmpty) {
      queue.value = [];
      await _player.stop();
      return;
    }

    final index = startIndex.clamp(0, tracks.length - 1);
    final sources = tracks
        .map((t) => AudioSource.file(t.path, tag: _trackToMediaItem(t)))
        .toList();

    await _playlist.clear();
    await _playlist.addAll(sources);
    await _player.setAudioSource(_playlist, initialIndex: index);

    queue.value = tracks.map(_trackToMediaItem).toList();
    mediaItem.add(_trackToMediaItem(tracks[index]));
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.durationMs > 0
          ? Duration(milliseconds: track.durationMs)
          : null,
      extras: {'trackId': track.id},
    );
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[event.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _player.seek(Duration.zero, index: index);
    mediaItem.add(_trackToMediaItem(_tracks[index]));
  }

  Future<void> _skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToNext() async {
    await _skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}

Future<void> initAudioService() async {
  await AudioService.init(
    builder: () => MusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.jamp.audio',
      androidNotificationChannelName: '${AppBranding.shortName} Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
