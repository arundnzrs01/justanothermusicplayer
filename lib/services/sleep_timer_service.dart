import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_music/application/playback_providers.dart';

class SleepTimerState {
  const SleepTimerState({this.remaining, this.endsAt});

  final Duration? remaining;
  final DateTime? endsAt;

  bool get isActive => remaining != null && remaining! > Duration.zero;

  SleepTimerState copyWith({Duration? remaining, DateTime? endsAt}) {
    return SleepTimerState(
      remaining: remaining ?? this.remaining,
      endsAt: endsAt ?? this.endsAt,
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier(this._pausePlayback) : super(const SleepTimerState());

  final Future<void> Function() _pausePlayback;
  Timer? _timer;
  DateTime? _endsAt;

  void start(Duration duration) {
    cancel();
    _endsAt = DateTime.now().add(duration);
    state = SleepTimerState(remaining: duration, endsAt: _endsAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_endsAt == null) return;
    final left = _endsAt!.difference(DateTime.now());
    if (left <= Duration.zero) {
      _onExpired();
      return;
    }
    state = SleepTimerState(remaining: left, endsAt: _endsAt);
  }

  Future<void> _onExpired() async {
    cancel();
    await _pausePlayback();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  final pause = ref.watch(playbackPauseProvider);
  return SleepTimerNotifier(pause);
});
