import 'package:flutter_test/flutter_test.dart';
import 'package:milow_core/milow_core.dart';

void main() {
  group('MilowGeofenceService Tests', () {
    const geofence = MilowGeofenceService();

    test('calculateDistanceMeters computes accurate distance between coordinates', () {
      // Coordinates approx 300 meters apart in Dallas, TX
      const startLat = 32.7767;
      const startLng = -96.7970;
      const endLat = 32.7790;
      const endLng = -96.7970;

      final distance = geofence.calculateDistanceMeters(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );

      expect(distance, greaterThan(200));
      expect(distance, lessThan(400));
    });

    test('isInsideGeofence returns true when within 500m radius', () {
      const currentLat = 32.7767;
      const currentLng = -96.7970;
      const targetLat = 32.7775; // ~88 meters away
      const targetLng = -96.7970;

      final isInside = geofence.isInsideGeofence(
        currentLat: currentLat,
        currentLng: currentLng,
        targetLat: targetLat,
        targetLng: targetLng,
        radiusMeters: 500.0,
      );

      expect(isInside, isTrue);
    });

    test('isInsideGeofence returns false when outside 500m radius', () {
      const currentLat = 32.7767;
      const currentLng = -96.7970;
      const targetLat = 32.7900; // ~1.4 km away
      const targetLng = -96.7970;

      final isInside = geofence.isInsideGeofence(
        currentLat: currentLat,
        currentLng: currentLng,
        targetLat: targetLat,
        targetLng: targetLng,
        radiusMeters: 500.0,
      );

      expect(isInside, isFalse);
    });
  });
}
