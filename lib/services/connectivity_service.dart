import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Monitors network type and exposes Wi-Fi vs cellular state.
class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _latest = results;
      _controller.add(isOnWifi);
    });
    _refresh();
  }

  final _controller = StreamController<bool>.broadcast();
  List<ConnectivityResult> _latest = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Stream<bool> get onWifiChanged => _controller.stream;

  bool get isOnWifi {
    if (_latest.isEmpty) return false;
    return _latest.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    );
  }

  bool get hasConnection {
    return _latest.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> checkIsOnWifi() async {
    final results = await Connectivity().checkConnectivity();
    _latest = results;
    return results.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    );
  }

  Future<void> _refresh() async {
    _latest = await Connectivity().checkConnectivity();
    _controller.add(isOnWifi);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

final isOnWifiProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield service.isOnWifi;
  yield* service.onWifiChanged;
});
