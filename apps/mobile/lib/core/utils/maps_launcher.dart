import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens turn-by-turn navigation to a destination in the platform maps app.
abstract final class MapsLauncher {
  /// Google Maps on Android, Apple Maps on iOS. Returns false if the
  /// launch failed (e.g. no maps app installed).
  static Future<bool> openNavigation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final query = label == null ? null : Uri.encodeComponent(label);
    final uri = Platform.isAndroid
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&destination=$latitude,$longitude'
            '${query == null ? '' : '&destination_place_name=$query'}',
          )
        : Uri.parse(
            'https://maps.apple.com/?daddr=$latitude,$longitude'
            '${query == null ? '' : '&q=$query'}',
          );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
