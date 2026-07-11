import 'package:torrent_music/services/logging/app_log_service.dart';

void logTap(String screen, String action, [String? detail]) {
  AppLog.tap(screen, action, detail: detail);
}
