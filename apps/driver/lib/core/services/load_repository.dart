import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/load_service.dart';

class LoadRepository {
  /// Get loads assigned to the driver
  static Future<List<Load>> getLoads({bool refresh = true}) async {
    // 1. Get from local DB first (Offline-First)
    final loadsQuery = driverDatabase.select(driverDatabase.loads);
    final List<LoadData> loadsData = await loadsQuery.get();

    final List<Load> loadedLoads = [];
    for (final data in loadsData) {
      final stopsQuery = driverDatabase.select(driverDatabase.stops)
        ..where((s) => s.loadId.equals(data.id))
        ..orderBy([(t) => OrderingTerm(expression: t.sequence)]);
      final List<StopData> stopsData = await stopsQuery.get();
      loadedLoads.add(_fromData(data, stopsData));
    }

    // 2. Trigger background refresh if online
    if (refresh && connectivityService.isOnline) {
      unawaited(_refreshFromServer());
    }

    return loadedLoads;
  }

  /// Refresh loads from the server
  static Future<void> _refreshFromServer() async {
    try {
      final remoteLoads = await LoadService.getAssignedLoads();

      await driverDatabase.transaction(() async {
        for (final load in remoteLoads) {
          // Check if there are local unsynced changes for this load
          final localLoad = await (driverDatabase.select(
            driverDatabase.loads,
          )..where((l) => l.id.equals(load.id))).getSingleOrNull();

          if (localLoad != null && !localLoad.isSynced) {
            // Keep local version until sync completes
            continue;
          }

          // Otherwise, update local storage
          await driverDatabase
              .into(driverDatabase.loads)
              .insertOnConflictUpdate(_toCompanion(load));

          // Sync stops: Delete old and insert new to ensure sequence/content match
          await (driverDatabase.delete(
            driverDatabase.stops,
          )..where((s) => s.loadId.equals(load.id))).go();
          for (final stop in load.stops) {
            await driverDatabase
                .into(driverDatabase.stops)
                .insert(_toStopCompanion(stop));
          }
        }
      });
    } catch (e) {
      debugPrint('[LoadRepository] Refresh failed: $e');
    }
  }

  /// Update load status (e.g., Accepting an assigned load)
  static Future<void> updateLoadStatus(String loadId, LoadStatus status) async {
    // 1. Update local cache immediately
    await (driverDatabase.update(
      driverDatabase.loads,
    )..where((l) => l.id.equals(loadId))).write(
      LoadsCompanion(
        status: Value(status.name),
        isSynced: const Value(false),
        lastUpdated: Value(DateTime.now()),
      ),
    );

    // 2. Enqueue sync operation
    await syncQueueService.enqueue(
      tableName: 'loads',
      operationType: 'update',
      payload: {
        'id': loadId,
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      localId: loadId,
    );
  }

  /// Update stop completion status
  static Future<void> updateStopStatus(
    String stopId,
    String loadId,
    bool isCompleted,
  ) async {
    final now = DateTime.now();

    // 1. Update stop record
    await (driverDatabase.update(
      driverDatabase.stops,
    )..where((s) => s.id.equals(stopId))).write(
      StopsCompanion(
        isCompleted: Value(isCompleted),
        completedAt: Value(isCompleted ? now : null),
      ),
    );

    // 2. Mark parent load as un-synced
    await (driverDatabase.update(
      driverDatabase.loads,
    )..where((l) => l.id.equals(loadId))).write(
      LoadsCompanion(isSynced: const Value(false), lastUpdated: Value(now)),
    );

    // 3. Enqueue sync operation
    await syncQueueService.enqueue(
      tableName: 'stops',
      operationType: 'update',
      payload: {
        'id': stopId,
        'is_completed': isCompleted,
        'completed_at': isCompleted ? now.toIso8601String() : null,
      },
      localId: stopId,
    );

    // 4. Update parent load status if needed
    if (isCompleted) {
      final stops = await getStopsForLoad(loadId);
      final allCompleted = stops.every((s) => s.isCompleted);
      if (allCompleted) {
        await updateLoadStatus(loadId, LoadStatus.completed);
      }
    }
  }

  static Future<void> updateStopArrival(
    String stopId,
    String loadId,
    DateTime arrivedAt,
  ) async {
    final now = DateTime.now();

    // 1. Update stop record
    await (driverDatabase.update(driverDatabase.stops)
          ..where((s) => s.id.equals(stopId)))
        .write(StopsCompanion(arrivedAt: Value(arrivedAt)));

    // 2. Mark parent load as un-synced
    await (driverDatabase.update(
      driverDatabase.loads,
    )..where((l) => l.id.equals(loadId))).write(
      LoadsCompanion(isSynced: const Value(false), lastUpdated: Value(now)),
    );

    // 3. Update load status to atStop
    await updateLoadStatus(loadId, LoadStatus.atStop);

    // 4. Enqueue sync operation
    await syncQueueService.enqueue(
      tableName: 'stops',
      operationType: 'update',
      payload: {'id': stopId, 'arrived_at': arrivedAt.toIso8601String()},
      localId: stopId,
    );
  }

  static Future<List<Stop>> getStopsForLoad(String loadId) async {
    final query = driverDatabase.select(driverDatabase.stops)
      ..where((s) => s.loadId.equals(loadId))
      ..orderBy([(t) => OrderingTerm(expression: t.sequence)]);
    final results = await query.get();
    return results.map((s) => _fromStopData(s)).toList();
  }

  // Conversion Helpers
  static Load _fromData(LoadData data, List<StopData> stopsData) {
    return Load(
      id: data.id,
      loadReference: data.loadReference,
      brokerId: data.brokerId,
      brokerName: data.brokerName,
      rate: data.rate,
      currency: data.currency,
      goods: data.goods,
      weight: data.weight,
      quantity: data.quantity,
      weightUnit: data.weightUnit,
      stops: stopsData.map((s) => _fromStopData(s)).toList(),
      status: LoadStatusX.fromString(data.status),
      loadNotes: data.loadNotes,
      companyNotes: data.companyNotes,
      assignedDriverId: data.assignedDriverId,
      assignedTruckId: data.assignedTruckId,
      assignedTrailerId: data.assignedTrailerId,
      tripNumber: data.tripNumber,
      poNumber: data.poNumber,
      companyId: data.companyId,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      accessorials: (jsonDecode(data.accessorials) as List)
          .map((e) => AccessorialCharge.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Stop _fromStopData(StopData data) {
    return Stop(
      id: data.id,
      loadId: data.loadId,
      sequence: data.sequence,
      type: StopType.values.byName(data.type),
      location: LoadLocation.fromMap(
        jsonDecode(data.location) as Map<String, dynamic>,
      ),
      notes: data.notes,
      commodity: data.commodity,
      quantity: data.quantity,
      weight: data.weight,
      weightUnit: data.weightUnit,
      stopReference: data.stopReference,
      instructions: data.instructions,
      appointmentTime: data.appointmentTime,
      isCompleted: data.isCompleted,
      completedAt: data.completedAt,
      arrivedAt: data.arrivedAt,
    );
  }

  static LoadsCompanion _toCompanion(Load load) {
    return LoadsCompanion(
      id: Value(load.id),
      loadReference: Value(load.loadReference),
      brokerId: Value(load.brokerId),
      brokerName: Value(load.brokerName),
      rate: Value(load.rate),
      currency: Value(load.currency),
      goods: Value(load.goods),
      weight: Value(load.weight),
      quantity: Value(load.quantity),
      weightUnit: Value(load.weightUnit),
      status: Value(load.status.name),
      loadNotes: Value(load.loadNotes),
      companyNotes: Value(load.companyNotes),
      assignedDriverId: Value(load.assignedDriverId),
      assignedTruckId: Value(load.assignedTruckId),
      assignedTrailerId: Value(load.assignedTrailerId),
      tripNumber: Value(load.tripNumber),
      poNumber: Value(load.poNumber),
      companyId: Value(load.companyId),
      createdAt: Value(load.createdAt),
      updatedAt: Value(load.updatedAt),
      accessorials: Value(
        jsonEncode(load.accessorials.map((e) => e.toJson()).toList()),
      ),
      isSynced: const Value(true),
      lastUpdated: Value(DateTime.now()),
    );
  }

  static StopsCompanion _toStopCompanion(Stop stop) {
    return StopsCompanion(
      id: Value(stop.id),
      loadId: Value(stop.loadId),
      sequence: Value(stop.sequence),
      type: Value(stop.type.name),
      location: Value(jsonEncode(stop.location.toJson())),
      notes: Value(stop.notes),
      commodity: Value(stop.commodity),
      quantity: Value(stop.quantity),
      weight: Value(stop.weight),
      weightUnit: Value(stop.weightUnit),
      stopReference: Value(stop.stopReference),
      instructions: Value(stop.instructions),
      appointmentTime: Value(stop.appointmentTime),
      isCompleted: Value(stop.isCompleted),
      completedAt: Value(stop.completedAt),
      arrivedAt: Value(stop.arrivedAt),
    );
  }
}
