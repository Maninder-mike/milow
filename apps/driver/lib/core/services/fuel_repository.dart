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
import 'package:fpdart/fpdart.dart';

/// Repository for fuel entries with offline-first support.
class FuelRepository {
  static const _uuid = Uuid();

  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      mockUserId ?? client.auth.currentUser?.id;

  /// Mock user ID for testing
  @visibleForTesting
  static String? mockUserId;

  /// Get all fuel entries for current user (local-first)
  static Future<Result<List<FuelEntry>>> getFuelEntries({
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      // Return cached data immediately
      final query = driverDatabase.select(driverDatabase.fuelEntries)
        ..where((f) => f.userId.equals(userId))
        ..orderBy([
          (f) => OrderingTerm(expression: f.fuelDate, mode: OrderingMode.desc),
        ]);
      final dataList = await query.get();
      final List<FuelEntry> cached = dataList.map((d) => _fromData(d)).toList();

      if (refresh && connectivityService.isOnline) {
        if (cached.isEmpty) {
          // Cache is empty (fresh install / flutter clean) — await server data
          return await _refreshFromServer(userId, supabaseClient: client);
        }
        // Cache has data — fire-and-forget refresh in background
        unawaited(_refreshFromServer(userId, supabaseClient: client));
      }

      return right(cached);
    } catch (e, stack) {
      return left(CacheFailure('Failed to load local fuel entries', stack));
    }
  }

  /// Watch all fuel entries for current user (reactive)
  static Stream<List<FuelEntry>> watchFuelEntries({SupabaseClient? supabaseClient}) {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return Stream.value([]);

    final query = driverDatabase.select(driverDatabase.fuelEntries)
      ..where((f) => f.userId.equals(userId))
      ..orderBy([
        (f) => OrderingTerm(expression: f.fuelDate, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((d) => _fromData(d)).toList());
  }

  /// Force refresh from server and update cache
  static Future<Result<List<FuelEntry>>> refresh({
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    return await _refreshFromServer(userId, supabaseClient: client);
  }

  static final _refreshLock = AsyncMutex();

  static Future<Result<List<FuelEntry>>> _refreshFromServer(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _refreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      final serverResult = await FuelService.getFuelEntries(
        supabaseClient: client,
      );

      return serverResult.fold(
        (failure) async {
           debugPrint('[FuelRepository] Failed to refresh: $failure');
           try {
             final List<FuelEntryData> dataList = await (driverDatabase.select(
               driverDatabase.fuelEntries,
             )..where((f) => f.userId.equals(userId))).get();
             return right(dataList.map((d) => _fromData(d)).toList());
           } catch(e, stack) {
             return left(CacheFailure('Failed to load local fallback fuel entries', stack));
           }
        },
        (serverEntries) async {
          try {
            // We don't delete locally added entries that haven't synced yet (those in sync_queue)
            final pendingCreateIds = syncQueueService.pendingOperations
                .where((op) => op.tableName == 'fuel_entries' && op.operationType == 'create')
                .map((op) => op.localId)
                .toSet();

            final pendingUpdateIds = syncQueueService.pendingOperations
                .where((op) => op.tableName == 'fuel_entries' && op.operationType == 'update')
                .map((op) => op.localId)
                .toSet();

            // Clear existing local cache for this user, except for pending creations and updates
            var deleteQuery = driverDatabase.delete(driverDatabase.fuelEntries)
              ..where((f) => f.userId.equals(userId));

            final idsToPreserve = {...pendingCreateIds, ...pendingUpdateIds};
            if (idsToPreserve.isNotEmpty) {
              deleteQuery = deleteQuery..where((f) => f.id.isNotIn(idsToPreserve.toList()));
            }

            await deleteQuery.go();

            // Update local cache with server data
            await driverDatabase.batch((batch) {
              for (final entry in serverEntries) {
                if (entry.id != null && pendingUpdateIds.contains(entry.id)) {
                  continue;
                }
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
            return right(serverEntries);
          } catch (e, stack) {
             return left(CacheFailure('Failed to write refreshed fuel data to cache', stack));
          }
        }
      );
    });
  }

  /// Get a single fuel entry by ID (local-first)
  static Future<Result<FuelEntry?>> getFuelEntryById(
    String entryId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      // Check local cache first
      final query = driverDatabase.select(driverDatabase.fuelEntries)
        ..where((f) => f.id.equals(entryId));
      final data = await query.getSingleOrNull();
      if (data != null) return right(_fromData(data));

      // Fallback to server if online
      if (connectivityService.isOnline) {
        return await FuelService.getFuelEntryById(
          entryId,
          supabaseClient: client,
        );
      }

      return right(null);
    } catch(e, stackTrace) {
        return left(UnexpectedFailure('Failed to lookup fuel entry by ID', originalError: e, stackTrace: stackTrace));
    }
  }

  /// Create a new fuel entry (offline-capable)
  static Future<Result<FuelEntry>> createFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    try {
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
      // Keep 'id' in payload to ensure client-side UUID is used on the server
      payload['user_id'] = userId;

      await syncQueueService.enqueue(
        tableName: 'fuel_entries',
        operationType: 'create',
        payload: payload,
        localId: localId,
      );

      // Trigger background sync
      unawaited(syncQueueService.processQueue(supabaseClient: client));

      return right(localEntry);
    } catch(e, stackTrace) {
      return left(CacheFailure('Failed to create local fuel entry', stackTrace));
    }
  }

  /// Update an existing fuel entry (offline-capable)
  static Future<Result<FuelEntry>> updateFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    if (entry.id == null) {
      return left(const ValidationFailure('Fuel entry ID is required for update'));
    }

    try {
      // Update local cache immediately
      final now = DateTime.now();
      final updatedEntry = entry.copyWith(updatedAt: now);

      await (driverDatabase.update(driverDatabase.fuelEntries)
            ..where((f) => f.id.equals(updatedEntry.id!)))
          .write(_toCompanion(updatedEntry));
      debugPrint('[FuelRepository] Updated locally: ${entry.id}');

      // Queue sync operation
      final payload = updatedEntry.toJson();

      await syncQueueService.enqueue(
        tableName: 'fuel_entries',
        operationType: 'update',
        payload: payload,
        localId: entry.id!,
      );

      // Trigger background sync
      unawaited(syncQueueService.processQueue(supabaseClient: client));

      return right(updatedEntry);
    } catch (e, stack) {
      return left(CacheFailure('Failed to update local fuel entry', stack));
    }
  }

  /// Delete a fuel entry (offline-capable)
  static Future<Result<Unit>> deleteFuelEntry(
    String entryId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    try {
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

      // Trigger background sync
      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(unit);
    } catch (e, stack) {
      return left(CacheFailure('Failed to delete local fuel entry', stack));
    }
  }

  /// Search fuel entries (local search if offline)
  static Future<Result<List<FuelEntry>>> searchFuelEntries(
    String query, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    if (connectivityService.isOnline) {
      final serverResult = await FuelService.searchFuelEntries(
        query,
        supabaseClient: client,
      );
      if (serverResult.isRight()) {
        return serverResult;
      }
      // If server result failed, fallback to local search
    }

    try {
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
      return right(dataList.map((d) => _fromData(d)).toList());
    } catch (e, stack) {
      return left(CacheFailure('Local search failed', stack));
    }
  }

  /// Clear local cache (for logout)
  static Future<Result<Unit>> clearCache() async {
    try {
      await driverDatabase.delete(driverDatabase.fuelEntries).go();
      return right(unit);
    } catch (e, stack) {
      return left(CacheFailure('Failed to clear cache', stack));
    }
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
      companyId: data.companyId,
    );
  }

  static FuelEntriesCompanion _toCompanion(FuelEntry entry) {
    return FuelEntriesCompanion(
      id: Value(entry.id!),
      userId: Value(entry.userId),
      companyId: Value(entry.companyId),
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
