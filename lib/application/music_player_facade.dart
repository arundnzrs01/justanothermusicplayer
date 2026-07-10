import 'dart:async';

import 'package:torrent_music/data/models/track.dart';
import 'package:torrent_music/domain/playback/play_strategy.dart';
import 'package:torrent_music/domain/playback/play_strategy_factory.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';

/// Facade — single entry point for playback orchestration.
class MusicPlayerFacade {
  MusicPlayerFacade({
    required PlaybackPort playback,
    PlayStrategyFactory? strategyFactory,
  })  : _playback = playback,
        _strategyFactory = strategyFactory ?? const PlayStrategyFactory();

  final PlaybackPort _playback;
  final PlayStrategyFactory _strategyFactory;

  List<Track> _queue = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequential;
  late PlayStrategy _strategy = _strategyFactory.create(_playMode);
  StreamSubscription<void>? _completionSub;

  PlaybackPort get playback => _playback;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;

  Track? get currentTrack =>
      _queue.isEmpty || _currentIndex >= _queue.length ? null : _queue[_currentIndex];

  void bindCompletionHandler(Future<void> Function() onCompleted) {
    _completionSub?.cancel();
    _completionSub = _playback.completedStream.listen((_) => onCompleted());
  }

  void dispose() => _completionSub?.cancel();

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) {
      _queue = [];
      _currentIndex = 0;
      await _playback.stop();
      return;
    }
    final index = startIndex.clamp(0, tracks.length - 1);
    _queue = List.of(tracks);
    _currentIndex = index;
    _strategy.onQueueChanged(_queue);
    await _playback.setQueue(tracks, startIndex: index);
    await _applyEngineMode();
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final tracks = queue ?? [track];
    final index = tracks.indexWhere((t) => t.path == track.path);
    await setQueue(tracks, startIndex: index >= 0 ? index : 0);
    await play();
  }

  Future<void> play() => _playback.play();
  Future<void> pause() => _playback.pause();
  Future<void> togglePlayPause() => _playback.isPlaying ? pause() : play();
  Future<void> seek(Duration position) => _playback.seek(position);

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    if (_playMode == PlayMode.sequential) {
      if (_playback.hasNext) {
        await _playback.seekToIndex((_playback.currentIndex ?? _currentIndex) + 1);
      }
      return;
    }
    final next = _strategy.nextIndex(_queue, _currentIndex);
    if (next != null) {
      _currentIndex = next;
      await _playback.seekToIndex(next);
    }
  }

  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;
    if (_playback.position.inSeconds > 3) {
      await _playback.seek(Duration.zero);
      return;
    }
    if (_playMode == PlayMode.sequential) {
      await _playback.seekToIndex(
        (_playback.currentIndex ?? _currentIndex) > 0
            ? (_playback.currentIndex ?? _currentIndex) - 1
            : 0,
      );
      return;
    }
    final prev = _strategy.previousIndex(_queue, _currentIndex);
    if (prev != null) {
      _currentIndex = prev;
      await _playback.seekToIndex(prev);
    } else {
      await _playback.seek(Duration.zero);
    }
  }

  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    _strategy = _strategyFactory.create(mode);
    _strategy.onQueueChanged(_queue);
    await _applyEngineMode();
  }

  Future<void> cyclePlayMode() => setPlayMode(_playMode.next);

  void syncIndex(int? index) {
    if (index != null && index < _queue.length) {
      _currentIndex = index;
    }
  }

  Future<void> onTrackCompleted() async {
    if (_playMode == PlayMode.repeatOne) {
      await _playback.seek(Duration.zero);
      await _playback.play();
      return;
    }
    final next = _strategy.nextIndex(_queue, _currentIndex);
    if (next != null) {
      _currentIndex = next;
      await _playback.seekToIndex(next);
      await _playback.play();
    }
  }

  Future<void> _applyEngineMode() async {
    await _playback.setShuffleEnabled(false);
    await _playback.setLoopOne(_playMode == PlayMode.repeatOne);
  }
}
