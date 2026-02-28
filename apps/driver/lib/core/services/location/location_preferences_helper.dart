import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/preferences_service.dart';

class LocationPreferencesHelper {
  /// Detect current country and update preferences if auto-update is enabled
  static Future<void> syncLocationPreferences(BuildContext context) async {
    final prefService = Provider.of<PreferencesService>(context, listen: false);

    // Only proceed if auto-update is enabled
    if (!prefService.getAutoUpdateUnits()) return;

    try {
      // 1. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // 2. Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy
              .low, // Low accuracy is enough for country detection
        ),
      );

      // 3. Reverse geocode to get country
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final country = placemarks.first.country;
        if (country != null && country.isNotEmpty) {
          await prefService.updateFromCountry(country);
        }
      }
    } catch (e) {
      debugPrint('Error syncing location preferences: $e');
    }
  }
}
