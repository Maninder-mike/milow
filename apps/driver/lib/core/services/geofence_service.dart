import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow_core/milow_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monitors driver location and triggers alerts when arriving at
/// pickup/delivery locations. Also auto-updates arrival time in database.
class GeofenceService {
  static final GeofenceService instance = GeofenceService._internal();
  factory GeofenceService() => instance;
  GeofenceService._internal();

  static const String _enabledKey = 'geofence_enabled';
  static const String _radiusKey = 'geofence_radius_meters';
  static const int _defaultRadiusMeters = 500;

  StreamSubscription<Position>? _positionSubscription;
  Trip? _activeTrip;
  final Map<String, _GeofenceLocation> _monitoredLocations = {};
  bool _isMonitoring = false;

  /// Whether geofence alerts are enabled
  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Set geofence enabled/disabled
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  /// Get geofence radius in meters
  Future<int> get radiusMeters async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_radiusKey) ?? _defaultRadiusMeters;
  }

  /// Set geofence radius
  Future<void> setRadiusMeters(int meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_radiusKey, meters);
  }

  /// Start monitoring for active trip arrivals
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    if (!await isEnabled) return;

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[GeofenceService] Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[GeofenceService] Location permission permanently denied');
      return;
    }

    // Get active trip
    _activeTrip = await TripRepository.getActiveTrip();
    if (_activeTrip == null) {
      debugPrint('[GeofenceService] No active trip to monitor');
      return;
    }

    // Geocode all pending locations
    await _geocodeTripLocations(_activeTrip!);

    if (_monitoredLocations.isEmpty) {
      debugPrint('[GeofenceService] No locations to monitor');
      return;
    }

    // Start position stream with battery-efficient settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100, // Only update every 100 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionUpdate);

    _isMonitoring = true;
    debugPrint(
      '[GeofenceService] Started monitoring ${_monitoredLocations.length} locations',
    );
  }

  /// Stop monitoring
  void stopMonitoring() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _monitoredLocations.clear();
    _activeTrip = null;
    _isMonitoring = false;
    debugPrint('[GeofenceService] Stopped monitoring');
  }

  /// Refresh monitoring (call when trip changes)
  Future<void> refreshMonitoring() async {
    stopMonitoring();
    await startMonitoring();
  }

  /// Geocode trip locations to coordinates
  Future<void> _geocodeTripLocations(Trip trip) async {
    _monitoredLocations.clear();

    // Process pickups
    for (int i = 0; i < trip.pickupLocations.length; i++) {
      // Skip if already has arrival time
      if (trip.pickupTimes.length > i && trip.pickupTimes[i] != null) {
        continue;
      }

      final location = trip.pickupLocations[i];
      final coords = await _geocodeAddress(location);
      if (coords != null) {
        _monitoredLocations['pickup_$i'] = _GeofenceLocation(
          name: location,
          latitude: coords.latitude,
          longitude: coords.longitude,
          isPickup: true,
          index: i,
        );
      }
    }

    // Process deliveries
    for (int i = 0; i < trip.deliveryLocations.length; i++) {
      // Skip if already has arrival time
      if (trip.deliveryTimes.length > i && trip.deliveryTimes[i] != null) {
        continue;
      }

      final location = trip.deliveryLocations[i];
      final coords = await _geocodeAddress(location);
      if (coords != null) {
        _monitoredLocations['delivery_$i'] = _GeofenceLocation(
          name: location,
          latitude: coords.latitude,
          longitude: coords.longitude,
          isPickup: false,
          index: i,
        );
      }
    }
  }

  /// Geocode a single address
  Future<Location?> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      return locations.isNotEmpty ? locations.first : null;
    } catch (e) {
      debugPrint('[GeofenceService] Failed to geocode "$address": $e');
      return null;
    }
  }

  /// Handle position updates
  Future<void> _onPositionUpdate(Position position) async {
    if (_activeTrip == null) return;

    final radius = await radiusMeters;
    final triggeredKeys = <String>[];

    for (final entry in _monitoredLocations.entries) {
      final loc = entry.value;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        loc.latitude,
        loc.longitude,
      );

      if (distance <= radius) {
        triggeredKeys.add(entry.key);
        await _onArrival(loc);
      }
    }

    // Remove triggered locations from monitoring
    for (final key in triggeredKeys) {
      _monitoredLocations.remove(key);
    }

    // Stop monitoring if no more locations
    if (_monitoredLocations.isEmpty) {
      stopMonitoring();
    }
  }

  /// Handle arrival at location
  Future<void> _onArrival(_GeofenceLocation location) async {
    final type = location.isPickup ? 'Pickup' : 'Delivery';
    debugPrint('[GeofenceService] Arrived at $type: ${location.name}');

    // 1. Show notification
    await notificationService.showArrivalNotification(
      locationType: type,
      locationName: location.name,
      tripNumber: _activeTrip?.tripNumber ?? '',
    );

    // 2. Update trip with arrival time
    await _updateTripArrivalTime(location);
  }

  /// Update trip arrival time in database
  Future<void> _updateTripArrivalTime(_GeofenceLocation location) async {
    if (_activeTrip == null) return;

    final now = DateTime.now();
    Trip updatedTrip;

    if (location.isPickup) {
      // Update pickup time at index
      final newPickupTimes = List<DateTime?>.from(_activeTrip!.pickupTimes);
      while (newPickupTimes.length <= location.index) {
        newPickupTimes.add(null);
      }
      newPickupTimes[location.index] = now;

      updatedTrip = _activeTrip!.copyWith(pickupTimes: newPickupTimes);
    } else {
      // Update delivery time at index
      final newDeliveryTimes = List<DateTime?>.from(_activeTrip!.deliveryTimes);
      while (newDeliveryTimes.length <= location.index) {
        newDeliveryTimes.add(null);
      }
      newDeliveryTimes[location.index] = now;

      updatedTrip = _activeTrip!.copyWith(deliveryTimes: newDeliveryTimes);
    }

    try {
      await TripRepository.updateTrip(updatedTrip);
      _activeTrip = updatedTrip;
      debugPrint('[GeofenceService] Updated arrival time for ${location.name}');
    } catch (e) {
      debugPrint('[GeofenceService] Failed to update arrival time: $e');
    }
  }
}

/// Internal class representing a monitored geofence location
class _GeofenceLocation {
  final String name;
  final double latitude;
  final double longitude;
  final bool isPickup;
  final int index;

  _GeofenceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isPickup,
    required this.index,
  });
}

/// Global instance
final geofenceService = GeofenceService.instance;
