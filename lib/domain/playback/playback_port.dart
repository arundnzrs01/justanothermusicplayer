import 'package:flutter/material.dart';
import 'package:torrent_music/data/models/track.dart';

/// Target interface for playback engines (Adapter pattern).
abstract class PlaybackPort {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<int?> get currentIndexStream;
  Stream<void> get completedStream;

  bool get isPlaying;
  int? get currentIndex;
  Duration get position;
  Duration? get duration;
  bool get hasNext;
  bool get hasPrevious;

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setLoopOne(bool enabled);
}

enum PlayMode {
  sequential,
  shuffle,
  repeatAll,
  repeatOne,
}

extension PlayModeX on PlayMode {
  String get label => switch (this) {
        PlayMode.sequential => 'Sequential',
        PlayMode.shuffle => 'Shuffle',
        PlayMode.repeatAll => 'Repeat all',
        PlayMode.repeatOne => 'Repeat one',
      };

  IconData get icon => switch (this) {
        PlayMode.sequential => Icons.playlist_play,
        PlayMode.shuffle => Icons.shuffle,
        PlayMode.repeatAll => Icons.repeat,
        PlayMode.repeatOne => Icons.repeat_one,
      };

  PlayMode get next => switch (this) {
        PlayMode.sequential => PlayMode.shuffle,
        PlayMode.shuffle => PlayMode.repeatAll,
        PlayMode.repeatAll => PlayMode.repeatOne,
        PlayMode.repeatOne => PlayMode.sequential,
      };
}
