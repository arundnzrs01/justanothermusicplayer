/// Live state while resolving magnet metadata before a download starts.
class MagnetMetadataPreview {
  const MagnetMetadataPreview({
    required this.prefetchId,
    this.isValid = true,
    this.isLoading = false,
    this.hasMetadata = false,
    this.displayName,
    this.errorMessage,
    this.phaseLabel,
    this.seeders = 0,
    this.leechers = 0,
  });

  final String prefetchId;
  final bool isValid;
  final bool isLoading;
  final bool hasMetadata;
  final String? displayName;
  final String? errorMessage;
  final String? phaseLabel;
  final int seeders;
  final int leechers;

  bool get canStartDownload => isValid && hasMetadata && errorMessage == null;
}

const kDownloadingMetadataLabel = 'Downloading metadata';
