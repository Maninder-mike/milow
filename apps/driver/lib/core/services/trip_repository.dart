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
  static String? get _userId => mockUserId ?? _client.auth.currentUser?.id;

  /// Mock user ID for testing
  @visibleForTesting
  static String? mockUserId;

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

      // Get pending sync operations to prevent overwriting/deleting unsynced data
      final pendingOps = syncQueueService.pendingOperations
          .where((op) => op.tableName == 'trips')
          .toList();

      final pendingCreateIds = pendingOps
          .where((op) => op.operationType == 'create')
          .map((op) => op.localId)
          .toSet();

      final pendingUpdateIds = pendingOps
          .where((op) => op.operationType == 'update')
          .map((op) => op.localId)
          .toSet();

      // Clear existing local cache for this user, BUT preserve pending creates
      final existingLocal = LocalTripStore.getAllForUser(userId);
      for (final trip in existingLocal) {
        if (trip.id != null) {
          // If this trip is pending creation, DON'T delete it locally
          // (Server doesn't have it yet, so if we delete, it's gone)
          if (pendingCreateIds.contains(trip.id)) {
            continue;
          }
          await LocalTripStore.delete(trip.id!);
        }
      }

      // Update local cache with server data, BUT respect pending updates
      for (final trip in serverTrips) {
        // If this trip has a pending local update, DON'T overwrite it with server data
        // (Local version is newer than server version)
        if (trip.id != null && pendingUpdateIds.contains(trip.id)) {
          continue;
        }
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

    // Queue sync operation (Soft Delete)
    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'update',
      payload: {
        'id': tripId,
        'user_id': userId,
        'deleted_at': DateTime.now().toIso8601String(),
      },
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

  /// Get active trip (trip that is not fully completed)
  /// A trip is active if it has no end_odometer OR has incomplete deliveries
  static Future<Trip?> getActiveTrip() async {
    final userId = _userId;
    if (userId == null) return null;

    // Check locally first
    final trips = LocalTripStore.getAllForUser(userId);

    // Find first trip that is not fully completed
    // Active = no end_odometer OR has incomplete deliveries
    final activeLocal = trips.where((t) {
      // Trip with no end odometer is always active
      if (t.endOdometer == null) return true;

      // Trip with incomplete deliveries is still active
      if (!t.allDeliveriesCompleted) return true;

      return false;
    }).firstOrNull;

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
