import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';

import 'package:drift/drift.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/fuel_service.dart';

/// Repository for fuel entries with offline-first support.
///
/// - Reads from local cache first (instant)
/// - Writes to local cache immediately + queues sync
/// - Background syncs when online
class FuelRepository {
  static const _uuid = Uuid();
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      mockUserId ?? client.auth.currentUser?.id;

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
    final query = driverDatabase.select(driverDatabase.fuelEntries)
      ..where((f) => f.userId.equals(userId));
    final dataList = await query.get();
    final List<FuelEntry> cached = dataList.map((d) => _fromData(d)).toList();

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

      // Clear existing local cache for this user
      await (driverDatabase.delete(
        driverDatabase.fuelEntries,
      )..where((f) => f.userId.equals(userId))).go();

      // Update local cache with server data
      await driverDatabase.batch((batch) {
        for (final entry in serverEntries) {
          batch.insert(
            driverDatabase.fuelEntries,
            _toCompanion(entry),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      debugPrint(
        '[FuelRepository] Refreshed ${serverEntries.length} entries from server',
      );
      return serverEntries;
    } catch (e) {
      debugPrint('[FuelRepository] Failed to refresh: $e');
      final List<FuelEntryData> dataList = await (driverDatabase.select(
        driverDatabase.fuelEntries,
      )..where((f) => f.userId.equals(userId))).get();
      return dataList.map((d) => _fromData(d)).toList();
    }
  }

  /// Get a single fuel entry by ID (local-first)
  static Future<FuelEntry?> getFuelEntryById(String entryId) async {
    // Check local cache first
    final query = driverDatabase.select(driverDatabase.fuelEntries)
      ..where((f) => f.id.equals(entryId));
    final data = await query.getSingleOrNull();
    if (data != null) return _fromData(data);

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await FuelService.getFuelEntryById(entryId);
    }

    return null;
  }

  /// Create a new fuel entry (offline-capable)
  static Future<FuelEntry> createFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
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
    await driverDatabase
        .into(driverDatabase.fuelEntries)
        .insert(_toCompanion(localEntry));
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
  static Future<FuelEntry> updateFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (entry.id == null) {
      throw Exception('Fuel entry ID is required for update');
    }

    // Update local cache immediately
    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await driverDatabase
        .update(driverDatabase.fuelEntries)
        .replace(_toCompanion(updatedEntry));
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
    await (driverDatabase.delete(
      driverDatabase.fuelEntries,
    )..where((f) => f.id.equals(entryId))).go();
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
    final queryLower = '%${query.toLowerCase()}%';
    final List<FuelEntryData> dataList =
        await (driverDatabase.select(driverDatabase.fuelEntries)..where(
              (f) =>
                  f.userId.equals(userId) &
                  (f.truckNumber.like(queryLower) |
                      f.reeferNumber.like(queryLower) |
                      f.location.like(queryLower)),
            ))
            .get();
    return dataList.map((d) => _fromData(d)).toList();
  }

  /// Clear local cache (for logout)
  static Future<void> clearCache() async {
    await driverDatabase.delete(driverDatabase.fuelEntries).go();
  }

  static FuelEntry _fromData(FuelEntryData data) {
    return FuelEntry(
      id: data.id,
      userId: data.userId,
      vehicleId: data.vehicleId,
      fuelDate: data.fuelDate,
      fuelType: data.fuelType,
      truckNumber: data.truckNumber,
      reeferNumber: data.reeferNumber,
      location: data.location,
      odometerReading: data.odometerReading,
      reeferHours: data.reeferHours,
      fuelQuantity: data.fuelQuantity,
      pricePerUnit: data.pricePerUnit,
      fuelUnit: data.fuelUnit,
      distanceUnit: data.distanceUnit,
      currency: data.currency,
      defQuantity: data.defQuantity,
      defPrice: data.defPrice,
      defFromYard: data.defFromYard,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  static FuelEntriesCompanion _toCompanion(FuelEntry entry) {
    return FuelEntriesCompanion(
      id: Value(entry.id!),
      userId: Value(entry.userId),
      vehicleId: Value(entry.vehicleId),
      fuelDate: Value(entry.fuelDate),
      fuelType: Value(entry.fuelType),
      truckNumber: Value(entry.truckNumber),
      reeferNumber: Value(entry.reeferNumber),
      location: Value(entry.location),
      odometerReading: Value(entry.odometerReading),
      reeferHours: Value(entry.reeferHours),
      fuelQuantity: Value(entry.fuelQuantity),
      pricePerUnit: Value(entry.pricePerUnit),
      fuelUnit: Value(entry.fuelUnit),
      distanceUnit: Value(entry.distanceUnit),
      currency: Value(entry.currency),
      defQuantity: Value(entry.defQuantity),
      defPrice: Value(entry.defPrice),
      defFromYard: Value(entry.defFromYard),
      createdAt: Value(entry.createdAt ?? DateTime.now()),
      updatedAt: Value(entry.updatedAt ?? DateTime.now()),
    );
  }
}
