enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.displayName,
    required this.magnetOrHash,
    required this.status,
    this.progress = 0,
    this.downSpeed = 0,
    this.upSpeed = 0,
    this.savePath,
    this.sourceName,
    this.seeders = 0,
    this.leechers = 0,
    this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.trackers = const [],
    this.waitingForWifi = false,
  });

  final String id;
  final String displayName;
  final String magnetOrHash;
  final DownloadStatus status;
  final double progress;
  final int downSpeed;
  final int upSpeed;
  final String? savePath;
  final String? sourceName;
  final int seeders;
  final int leechers;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final List<String> trackers;
  final bool waitingForWifi;

  DownloadItem copyWith({
    String? id,
    String? displayName,
    String? magnetOrHash,
    DownloadStatus? status,
    double? progress,
    int? downSpeed,
    int? upSpeed,
    String? savePath,
    String? sourceName,
    int? seeders,
    int? leechers,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    List<String>? trackers,
    bool? waitingForWifi,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      magnetOrHash: magnetOrHash ?? this.magnetOrHash,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downSpeed: downSpeed ?? this.downSpeed,
      upSpeed: upSpeed ?? this.upSpeed,
      savePath: savePath ?? this.savePath,
      sourceName: sourceName ?? this.sourceName,
      seeders: seeders ?? this.seeders,
      leechers: leechers ?? this.leechers,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      trackers: trackers ?? this.trackers,
      waitingForWifi: waitingForWifi ?? this.waitingForWifi,
    );
  }
}
