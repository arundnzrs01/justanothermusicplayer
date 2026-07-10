import 'package:torrent_music/domain/playback/play_strategy.dart';
import 'package:torrent_music/domain/playback/playback_port.dart';

/// Factory for creating play strategies (Factory pattern).
class PlayStrategyFactory {
  const PlayStrategyFactory();

  PlayStrategy create(PlayMode mode) => switch (mode) {
        PlayMode.sequential => SequentialPlayStrategy(),
        PlayMode.shuffle => ShufflePlayStrategy(),
        PlayMode.repeatAll => RepeatAllPlayStrategy(),
        PlayMode.repeatOne => RepeatOnePlayStrategy(),
      };
}
