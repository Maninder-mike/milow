import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';

import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/local_fuel_store.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/fuel_service.dart';

/// Repository for fuel entries with offline-first support.
///
/// - Reads from local cache first (instant)
/// - Writes to local cache immediately + queues sync
/// - Background syncs when online
class FuelRepository {
  static const _uuid = Uuid();
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => mockUserId ?? _client.auth.currentUser?.id;

  /// Mock user ID for testing
  @visibleForTesting
  static String? mockUserId;

  /// Get all fuel entries for current user (local-first)
  static Future<List<FuelEntry>> getFuelEntries({bool refresh = true}) async {
    final userId = _userId;
    if (userId == null) return [];

    // Return cached data immediately
    final cached = LocalFuelStore.getAllForUser(userId);

    if (refresh && connectivityService.isOnline) {
      // Fire-and-forget refresh
      unawaited(_refreshFromServer(userId));
    }

    return cached;
  }

  /// Force refresh from server and update cache
  static Future<List<FuelEntry>> refresh() async {
    final userId = _userId;
    if (userId == null) return [];

    return await _refreshFromServer(userId);
  }

  static Future<List<FuelEntry>> _refreshFromServer(String userId) async {
    try {
      final serverEntries = await FuelService.getFuelEntries();

      // Clear existing local cache for this user to prevent duplicates
      // (local entries may have different IDs than server entries)
      final existingLocal = LocalFuelStore.getAllForUser(userId);
      for (final entry in existingLocal) {
        if (entry.id != null) {
          await LocalFuelStore.delete(entry.id!);
        }
      }

      // Update local cache with server data
      for (final entry in serverEntries) {
        await LocalFuelStore.put(entry);
      }

      debugPrint(
        '[FuelRepository] Refreshed ${serverEntries.length} entries from server',
      );
      return serverEntries;
    } catch (e) {
      debugPrint('[FuelRepository] Failed to refresh: $e');
      return LocalFuelStore.getAllForUser(userId);
    }
  }

  /// Get a single fuel entry by ID (local-first)
  static Future<FuelEntry?> getFuelEntryById(String entryId) async {
    // Check local cache first
    final cached = LocalFuelStore.get(entryId);
    if (cached != null) return cached;

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await FuelService.getFuelEntryById(entryId);
    }

    return null;
  }

  /// Create a new fuel entry (offline-capable)
  static Future<FuelEntry> createFuelEntry(FuelEntry entry) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Generate local ID if not present
    final localId = entry.id ?? _uuid.v4();
    final localEntry = entry.copyWith(
      id: localId,
      userId: userId,
      createdAt: DateTime.now(),
    );

    // Save to local cache immediately
    await LocalFuelStore.put(localEntry);
    debugPrint('[FuelRepository] Created locally: $localId');

    // Queue sync operation
    final payload = localEntry.toJson();
    payload['user_id'] = userId;
    payload.remove('id');

    await syncQueueService.enqueue(
      tableName: 'fuel_entries',
      operationType: 'create',
      payload: payload,
      localId: localId,
    );

    return localEntry;
  }

  /// Update an existing fuel entry (offline-capable)
  static Future<FuelEntry> updateFuelEntry(FuelEntry entry) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (entry.id == null) {
      throw Exception('Fuel entry ID is required for update');
    }

    // Update local cache immediately
    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await LocalFuelStore.put(updatedEntry);
    debugPrint('[FuelRepository] Updated locally: ${entry.id}');

    // Queue sync operation
    final payload = updatedEntry.toJson();
    payload['updated_at'] = DateTime.now().toIso8601String();

    await syncQueueService.enqueue(
      tableName: 'fuel_entries',
      operationType: 'update',
      payload: payload,
      localId: entry.id!,
    );

    return updatedEntry;
  }

  /// Delete a fuel entry (offline-capable)
  static Future<void> deleteFuelEntry(String entryId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Delete from local cache immediately
    await LocalFuelStore.delete(entryId);
    debugPrint('[FuelRepository] Deleted locally: $entryId');

    // Queue sync operation (Soft Delete)
    await syncQueueService.enqueue(
      tableName: 'fuel_entries',
      operationType: 'update',
      payload: {
        'id': entryId,
        'user_id': userId,
        'deleted_at': DateTime.now().toIso8601String(),
      },
      localId: entryId,
    );
  }

  /// Search fuel entries (local search if offline)
  static Future<List<FuelEntry>> searchFuelEntries(String query) async {
    final userId = _userId;
    if (userId == null) return [];

    if (connectivityService.isOnline) {
      try {
        return await FuelService.searchFuelEntries(query);
      } catch (_) {
        // Fallback to local search
      }
    }

    // Local search
    final all = LocalFuelStore.getAllForUser(userId);
    final queryLower = query.toLowerCase();
    return all.where((entry) {
      return (entry.truckNumber?.toLowerCase().contains(queryLower) ?? false) ||
          (entry.reeferNumber?.toLowerCase().contains(queryLower) ?? false) ||
          (entry.location?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  /// Clear local cache (for logout)
  static Future<void> clearCache() async {
    await LocalFuelStore.clear();
  }
}
