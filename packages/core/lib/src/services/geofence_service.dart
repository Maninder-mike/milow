import 'dart:math';

/// Industry-standard geofencing service ($0 external API cost).
///
/// Uses the Haversine formula to compute geodesic distance between driver GPS
/// coordinates and warehouse stop targets. Standard industry radius: 500 meters (0.3 miles).
class MilowGeofenceService {
  const MilowGeofenceService();

  static const double defaultRadiusMeters = 500.0; // Industry standard (~0.3 miles)
  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates distance in meters between two lat/long coordinates.
  double calculateDistanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLat)) *
            cos(_toRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Checks if current location is within target stop geofence.
  bool isInsideGeofence({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    double radiusMeters = defaultRadiusMeters,
  }) {
    final distance = calculateDistanceMeters(
      startLat: currentLat,
      startLng: currentLng,
      endLat: targetLat,
      endLng: targetLng,
    );
    return distance <= radiusMeters;
  }

  double _toRadians(double degree) => degree * (pi / 180.0);
}
