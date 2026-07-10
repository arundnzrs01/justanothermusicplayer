/// Public tracker list defaults from [ngosang/trackerslist](https://github.com/ngosang/trackerslist).
abstract final class TrackerListConfig {
  static const String sourceName = 'ngosang/trackerslist';
  static const String listFile = 'trackers_all.txt';

  /// Raw GitHub URL — updated daily by upstream.
  static const String defaultListUrl =
      'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt';

  static const Duration autoUpdateInterval = Duration(hours: 24);
}
