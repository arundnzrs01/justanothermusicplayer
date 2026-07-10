import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/application/music_player_facade.dart';
import 'package:torrent_music/application/playback_providers.dart';
import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';

class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.sequential,
    this.waveform = const [],
  });

  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlayMode playMode;
  final List<double> waveform;

  bool get shuffleEnabled => playMode == PlayMode.shuffle;

  Track? get currentTrack =>
      queue.isEmpty || currentIndex >= queue.length ? null : queue[currentIndex];

  List<Track> get upcomingTracks {
    if (queue.isEmpty || currentIndex >= queue.length - 1) return [];
    return queue.sublist(currentIndex + 1);
  }

  PlayerState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    PlayMode? playMode,
    List<double>? waveform,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      waveform: waveform ?? this.waveform,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier(this._facade, this._playback) : super(const PlayerState()) {
    _facade.bindCompletionHandler(_onTrackCompleted);
    _playback.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });
    _playback.durationStream.listen((duration) {
      state = state.copyWith(duration: duration ?? Duration.zero);
    });
    _playback.playingStream.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    });
    _playback.currentIndexStream.listen((index) {
      _facade.syncIndex(index);
      if (index != null && index < state.queue.length) {
        state = state.copyWith(
          currentIndex: index,
          waveform: _generateWaveform(state.queue[index].path),
        );
      }
    });
  }

  final MusicPlayerFacade _facade;
  final PlaybackPort _playback;

  Future<void> _onTrackCompleted() async {
    await _facade.onTrackCompleted();
    _syncFromFacade();
  }

  void _syncFromFacade() {
    state = state.copyWith(
      queue: _facade.queue,
      currentIndex: _facade.currentIndex,
      playMode: _facade.playMode,
    );
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) {
      state = const PlayerState();
      await _facade.setQueue([]);
      return;
    }
    final index = startIndex.clamp(0, tracks.length - 1);
    await _facade.setQueue(tracks, startIndex: index);
    state = state.copyWith(
      queue: _facade.queue,
      currentIndex: index,
      playMode: _facade.playMode,
      waveform: _generateWaveform(tracks[index].path),
    );
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    await _facade.playTrack(track, queue: queue);
    final current = _facade.currentTrack;
    if (current != null) {
      state = state.copyWith(
        queue: _facade.queue,
        currentIndex: _facade.currentIndex,
        playMode: _facade.playMode,
        isPlaying: true,
        waveform: _generateWaveform(current.path),
      );
    }
  }

  Future<void> play() => _facade.play();
  Future<void> pause() => _facade.pause();
  Future<void> togglePlayPause() => _facade.togglePlayPause();
  Future<void> seek(Duration position) => _facade.seek(position);
  Future<void> skipNext() => _facade.skipNext();
  Future<void> skipPrevious() => _facade.skipPrevious();

  Future<void> toggleShuffle() async {
    final next = state.playMode == PlayMode.shuffle
        ? PlayMode.sequential
        : PlayMode.shuffle;
    await _facade.setPlayMode(next);
    _syncFromFacade();
  }

  Future<void> cyclePlayMode() async {
    await _facade.cyclePlayMode();
    _syncFromFacade();
  }

  List<double> _generateWaveform(String path) {
    final seed = path.hashCode;
    final rng = Random(seed);
    return List.generate(64, (_) => 0.15 + rng.nextDouble() * 0.85);
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final facade = ref.watch(musicPlayerFacadeProvider);
  final playback = ref.watch(playbackPortProvider);
  return PlayerNotifier(facade, playback);
});
