import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Local Hive store for trips.
///
/// Provides immediate local access to trip data while syncing
/// happens in the background.
class LocalTripStore {
  static const String _boxName = 'trips';

  static Box<String>? _box;

  /// Initialize the store
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('[LocalTripStore] Initialized, items: ${_box?.length}');
  }

  static Box<String> get _ensureBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalTripStore.init() must be called before use');
    }
    return box;
  }

  /// Get a trip by ID
  static Trip? get(String id) {
    final jsonStr = _ensureBox.get(id);
    if (jsonStr == null) return null;
    try {
      return Trip.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Get all trips for a user
  static List<Trip> getAllForUser(String userId) {
    final trips = <Trip>[];
    for (final jsonStr in _ensureBox.values) {
      try {
        final trip = Trip.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        if (trip.userId == userId) {
          trips.add(trip);
        }
      } catch (_) {
        // Skip invalid entries
      }
    }

    // De-duplicate by trip_number (keep the one with the most recent createdAt)
    // This handles cases where a trip exists with both a local UUID and server ID
    final Map<String, Trip> uniqueByTripNumber = {};
    for (final trip in trips) {
      final key = trip.tripNumber.toUpperCase();
      final existing = uniqueByTripNumber[key];
      if (existing == null) {
        uniqueByTripNumber[key] = trip;
      } else {
        // Keep the one with a later createdAt
        if (trip.createdAt != null && existing.createdAt != null) {
          if (trip.createdAt!.isAfter(existing.createdAt!)) {
            uniqueByTripNumber[key] = trip;
          }
        } else if (trip.createdAt != null) {
          uniqueByTripNumber[key] = trip; // Prefer the one with createdAt
        }
      }
    }

    final uniqueTrips = uniqueByTripNumber.values.toList();
    // Sort by date descending
    uniqueTrips.sort((a, b) => b.tripDate.compareTo(a.tripDate));
    return uniqueTrips;
  }

  /// Save a trip
  static Future<void> put(Trip trip) async {
    if (trip.id == null) return;
    final jsonStr = json.encode(trip.toJson());
    await _ensureBox.put(trip.id, jsonStr);
  }

  /// Delete a trip
  static Future<void> delete(String id) async {
    await _ensureBox.delete(id);
  }

  /// Clear all trips (for logout)
  static Future<void> clear() async {
    await _ensureBox.clear();
  }

  /// Watch for changes
  static ValueListenable<Box<String>> watchBox() => _ensureBox.listenable();
}
