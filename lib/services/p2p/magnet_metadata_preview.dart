/// Live state while resolving magnet metadata before a download starts.
class MagnetMetadataPreview {
  const MagnetMetadataPreview({
    required this.prefetchId,
    this.isValid = true,
    this.isLoading = false,
    this.hasMetadata = false,
    this.isCompleted = false,
    this.progress = 0,
    this.displayName,
    this.errorMessage,
    this.phaseLabel,
    this.seeders = 0,
    this.leechers = 0,
    this.continuingExisting = false,
  });

  final String prefetchId;
  final bool isValid;
  final bool isLoading;
  final bool hasMetadata;
  final bool isCompleted;
  final double progress;
  final String? displayName;
  final String? errorMessage;
  final String? phaseLabel;
  final int seeders;
  final int leechers;
  final bool continuingExisting;

  bool get canStartDownload =>
      isValid &&
      errorMessage == null &&
      progress < 0.99 &&
      (hasMetadata || isCompleted);
}

const kDownloadingMetadataLabel = 'Downloading metadata';
