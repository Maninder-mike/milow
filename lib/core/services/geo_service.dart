import 'package:geocoding/geocoding.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// Service to handle geocoding and caching of coordinates
class GeoService {
  static const String _boxName = 'geo_cache';

  /// Initialize Hive box for caching
  static Future<void> init() async {
    await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
  }

  /// Get coordinates from address string (e.g., "City, ST")
  /// Checks cache first, then calls Geocoding API
  static Future<LatLng?> getCoordinates(String address) async {
    if (address.isEmpty) return null;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    }
    final box = Hive.box<Map<dynamic, dynamic>>(_boxName);

    // Normalize address key
    final key = address.toLowerCase().trim();

    // Check cache
    if (box.containsKey(key)) {
      final data = box.get(key);
      if (data != null) {
        return LatLng(data['lat'] as double, data['lng'] as double);
      }
    }

    // Fetch from API
    try {
      // Add "USA" or "Canada" context if missing to improve accuracy?
      // For now, rely on geocoder's ability.

      final List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        final coords = LatLng(loc.latitude, loc.longitude);

        // Cache result
        await box.put(key, {
          'lat': loc.latitude,
          'lng': loc.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        return coords;
      }
    } catch (e) {
      debugPrint('GeoService Error for "$address": $e');
      // If error is due to request limit or network, we might want to return null
      // without caching a failure.
    }

    return null;
  }

  /// Clear cache
  static Future<void> clearCache() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_boxName);
    await box.clear();
  }
}
