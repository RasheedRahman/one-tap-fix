import 'package:flutter/material.dart';

/// Global navigator key so non-widget code (e.g. FCM notification taps)
/// can push screens. Attached to the root [MaterialApp] in app.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Helpers for pushing from outside the widget tree.
abstract final class AppNavigator {
  static bool push(Widget screen) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
    return true;
  }
}
