import 'package:torrent_music/data/models/track.dart';

/// Strategy interface for queue navigation algorithms.
abstract class PlayStrategy {
  int? nextIndex(List<Track> queue, int currentIndex);
  int? previousIndex(List<Track> queue, int currentIndex);
  void onQueueChanged(List<Track> queue);
}

/// Default in-order playback.
class SequentialPlayStrategy implements PlayStrategy {
  @override
  void onQueueChanged(List<Track> queue) {}

  @override
  int? nextIndex(List<Track> queue, int currentIndex) {
    final next = currentIndex + 1;
    return next < queue.length ? next : null;
  }

  @override
  int? previousIndex(List<Track> queue, int currentIndex) {
    return currentIndex > 0 ? currentIndex - 1 : null;
  }
}

/// Randomized order with history for back navigation.
class ShufflePlayStrategy implements PlayStrategy {
  List<int> _order = [];
  int _position = 0;

  @override
  void onQueueChanged(List<Track> queue) {
    _order = List.generate(queue.length, (i) => i)..shuffle();
    _position = 0;
  }

  @override
  int? nextIndex(List<Track> queue, int currentIndex) {
    if (queue.isEmpty) return null;
    if (_order.isEmpty) onQueueChanged(queue);
    if (_position + 1 >= _order.length) return null;
    _position++;
    return _order[_position];
  }

  @override
  int? previousIndex(List<Track> queue, int currentIndex) {
    if (_position <= 0) return null;
    _position--;
    return _order[_position];
  }
}

/// Loops back to start when queue ends.
class RepeatAllPlayStrategy implements PlayStrategy {
  final _sequential = SequentialPlayStrategy();

  @override
  void onQueueChanged(List<Track> queue) => _sequential.onQueueChanged(queue);

  @override
  int? nextIndex(List<Track> queue, int currentIndex) {
    if (queue.isEmpty) return null;
    final next = currentIndex + 1;
    return next < queue.length ? next : 0;
  }

  @override
  int? previousIndex(List<Track> queue, int currentIndex) {
    if (queue.isEmpty) return null;
    return currentIndex > 0 ? currentIndex - 1 : queue.length - 1;
  }
}

/// Replays the current track.
class RepeatOnePlayStrategy implements PlayStrategy {
  @override
  void onQueueChanged(List<Track> queue) {}

  @override
  int? nextIndex(List<Track> queue, int currentIndex) => currentIndex;

  @override
  int? previousIndex(List<Track> queue, int currentIndex) => currentIndex;
}
