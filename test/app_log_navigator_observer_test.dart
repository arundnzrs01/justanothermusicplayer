import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_music/services/logging/app_log_navigator_observer.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/jamp_test_logs';
      }
      return null;
    });
    await AppLog.init(sessionDetail: 'test session');
  });

  tearDown(() async {
    await AppLog.I.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('push and pop produce NAV log lines', () async {
    final observer = AppLogNavigatorObserver();
    final home = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/home'),
      builder: (_) => const SizedBox(),
    );
    final downloads = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/downloads'),
      builder: (_) => const SizedBox(),
    );

    observer.didPush(downloads, home);
    observer.didPop(downloads, home);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    final logFile = AppLog.I.currentLogFile;
    expect(logFile, isNotNull);
    final contents = await AppLog.readLogFile(logFile!.path);

    expect(contents, contains('[NAV]'));
    expect(contents, contains('/home'));
    expect(contents, contains('/downloads'));
    expect(contents, contains('push'));
    expect(contents, contains('pop'));
  });
}
