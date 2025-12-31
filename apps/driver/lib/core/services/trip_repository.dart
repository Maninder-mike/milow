import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';

import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/local_trip_store.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/trip_service.dart';

/// Repository for trips with offline-first support.
///
/// - Reads from local cache first (instant)
/// - Writes to local cache immediately + queues sync
/// - Background syncs when online
class TripRepository {
  static const _uuid = Uuid();
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => _client.auth.currentUser?.id;

  /// Get all trips for current user (local-first)
  ///
  /// Returns cached data immediately. If [refresh] is true, also
  /// fetches from server in the background.
  static Future<List<Trip>> getTrips({bool refresh = true}) async {
    final userId = _userId;
    if (userId == null) return [];

    // Return cached data immediately
    final cached = LocalTripStore.getAllForUser(userId);

    if (refresh && connectivityService.isOnline) {
      // Fire-and-forget refresh
      unawaited(_refreshFromServer(userId));
    }

    return cached;
  }

  /// Force refresh from server and update cache
  static Future<List<Trip>> refresh() async {
    final userId = _userId;
    if (userId == null) return [];

    return await _refreshFromServer(userId);
  }

  static Future<List<Trip>> _refreshFromServer(String userId) async {
    try {
      final serverTrips = await TripService.getTrips();

      // Update local cache with server data
      for (final trip in serverTrips) {
        await LocalTripStore.put(trip);
      }

      debugPrint(
        '[TripRepository] Refreshed ${serverTrips.length} trips from server',
      );
      return serverTrips;
    } catch (e) {
      debugPrint('[TripRepository] Failed to refresh: $e');
      // Return cached data on failure
      return LocalTripStore.getAllForUser(userId);
    }
  }

  /// Get a single trip by ID (local-first)
  static Future<Trip?> getTripById(String tripId) async {
    // Check local cache first
    final cached = LocalTripStore.get(tripId);
    if (cached != null) return cached;

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await TripService.getTripById(tripId);
    }

    return null;
  }

  /// Create a new trip (offline-capable)
  ///
  /// Saves to local cache immediately and queues sync.
  /// Returns the trip with a local ID that will be synced.
  static Future<Trip> createTrip(Trip trip) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Generate local ID if not present
    final localId = trip.id ?? _uuid.v4();
    final localTrip = trip.copyWith(
      id: localId,
      userId: userId,
      createdAt: DateTime.now(),
    );

    // Save to local cache immediately
    await LocalTripStore.put(localTrip);
    debugPrint('[TripRepository] Created locally: $localId');

    // Queue sync operation
    final payload = localTrip.toJson();
    payload['user_id'] = userId;
    payload.remove('id'); // Server will generate its own ID

    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'create',
      payload: payload,
      localId: localId,
    );

    return localTrip;
  }

  /// Update an existing trip (offline-capable)
  static Future<Trip> updateTrip(Trip trip) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (trip.id == null) {
      throw Exception('Trip ID is required for update');
    }

    // Update local cache immediately
    final updatedTrip = trip.copyWith(updatedAt: DateTime.now());

    await LocalTripStore.put(updatedTrip);
    debugPrint('[TripRepository] Updated locally: ${trip.id}');

    // Queue sync operation
    final payload = updatedTrip.toJson();
    payload['updated_at'] = DateTime.now().toIso8601String();

    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'update',
      payload: payload,
      localId: trip.id!,
    );

    return updatedTrip;
  }

  /// Delete a trip (offline-capable)
  static Future<void> deleteTrip(String tripId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Delete from local cache immediately
    await LocalTripStore.delete(tripId);
    debugPrint('[TripRepository] Deleted locally: $tripId');

    // Queue sync operation
    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'delete',
      payload: {'id': tripId, 'user_id': userId},
      localId: tripId,
    );
  }

  /// Search trips (local search if offline, server if online)
  static Future<List<Trip>> searchTrips(String query) async {
    final userId = _userId;
    if (userId == null) return [];

    if (connectivityService.isOnline) {
      try {
        return await TripService.searchTrips(query);
      } catch (_) {
        // Fallback to local search
      }
    }

    // Local search
    final all = LocalTripStore.getAllForUser(userId);
    final queryLower = query.toLowerCase();
    return all.where((trip) {
      return trip.tripNumber.toLowerCase().contains(queryLower) ||
          trip.truckNumber.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Get active trip (trip without end odometer)
  static Future<Trip?> getActiveTrip() async {
    final userId = _userId;
    if (userId == null) return null;

    // Check locally first
    final trips = LocalTripStore.getAllForUser(userId);
    final activeLocal = trips.where((t) => t.endOdometer == null).firstOrNull;

    if (activeLocal != null) return activeLocal;

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await TripService.getActiveTrip();
    }

    return null;
  }

  /// Clear local cache (for logout)
  static Future<void> clearCache() async {
    await LocalTripStore.clear();
  }
}
