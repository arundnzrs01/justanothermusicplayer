import 'package:flutter/material.dart';
import 'package:torrent_music/services/logging/app_log_service.dart';

/// Logs route push/pop/replace events via [AppLog.nav].
class AppLogNavigatorObserver extends NavigatorObserver {
  String? _currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logTransition('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logTransition('pop', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final from = _routeName(oldRoute);
    final to = _routeName(newRoute);
    AppLog.nav('$from → $to (replace)');
    _currentRoute = to;
  }

  void _logTransition(
    String action,
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    final from = _routeName(previousRoute) ?? _currentRoute ?? '/';
    final to = _routeName(route) ?? '/';
    AppLog.nav('$from → $to ($action)');
    _currentRoute = to;
  }

  String? _routeName(Route<dynamic>? route) {
    if (route == null) return null;
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.settings.arguments?.toString();
  }
}
