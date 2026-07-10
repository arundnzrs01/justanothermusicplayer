import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';
import 'package:torrent_music/services/audio/music_audio_handler.dart';

/// Adapts [MusicAudioHandler] to the uniform [PlaybackPort] interface.
class JustAudioPlaybackAdapter implements PlaybackPort {
  JustAudioPlaybackAdapter(this._handler) {
    _handler.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _completedController.add(null);
      }
    });
  }

  final MusicAudioHandler _handler;
  final _completedController = StreamController<void>.broadcast();

  @override
  Stream<Duration> get positionStream => _handler.player.positionStream;

  @override
  Stream<Duration?> get durationStream => _handler.player.durationStream;

  @override
  Stream<bool> get playingStream =>
      _handler.player.playerStateStream.map((s) => s.playing);

  @override
  Stream<int?> get currentIndexStream => _handler.player.currentIndexStream;

  @override
  Stream<void> get completedStream => _completedController.stream;

  @override
  bool get isPlaying => _handler.player.playing;

  @override
  int? get currentIndex => _handler.player.currentIndex;

  @override
  Duration get position => _handler.player.position;

  @override
  Duration? get duration => _handler.player.duration;

  @override
  bool get hasNext => _handler.player.hasNext;

  @override
  bool get hasPrevious => _handler.player.hasPrevious;

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) =>
      _handler.setTrackQueue(tracks, startIndex: startIndex);

  @override
  Future<void> play() => _handler.play();

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> stop() => _handler.stop();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<void> seekToIndex(int index) => _handler.skipToQueueItem(index);

  @override
  Future<void> setShuffleEnabled(bool enabled) =>
      _handler.player.setShuffleModeEnabled(enabled);

  @override
  Future<void> setLoopOne(bool enabled) => _handler.player.setLoopMode(
        enabled ? LoopMode.one : LoopMode.off,
      );
}
