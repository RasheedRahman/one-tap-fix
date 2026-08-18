import 'dart:math';

/// Geographic helpers used by matching and job cards.
abstract final class Geo {
  static const double _earthRadiusKm = 6371.0;

  /// Great-circle distance between two coordinates in kilometres.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Urban average speed assumption (30 km/h) with a 10-minute floor —
  /// matches the plan's "nearest technician within 10 minutes" promise.
  static int etaMinutesForKm(double km) {
    final minutes = (km / 30.0 * 60.0).ceil();
    return max(10, minutes);
  }

  static double _radians(double degrees) => degrees * pi / 180.0;
}
