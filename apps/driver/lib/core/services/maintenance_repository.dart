import 'dart:async';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MaintenanceRepository {
  static const _uuid = Uuid();

  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      client.auth.currentUser?.id;

  /// Watch cached vehicles list
  static Stream<List<Vehicle>> watchVehicles({SupabaseClient? supabaseClient}) {
    return driverDatabase.select(driverDatabase.vehicles).watch().map(
          (rows) => rows.map((d) => _fromVehicleData(d)).toList(),
        );
  }

  /// Get cached vehicles list, refreshing from server if online
  static Future<Result<List<Vehicle>>> getVehicles({
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final dataList = await driverDatabase.select(driverDatabase.vehicles).get();
      final cached = dataList.map((d) => _fromVehicleData(d)).toList();

      if (refresh && connectivityService.isOnline) {
        if (cached.isEmpty) {
          return await _refreshVehiclesFromServer(userId, supabaseClient: client);
        }
        unawaited(_refreshVehiclesFromServer(userId, supabaseClient: client));
      }

      return right(cached);
    } catch (e, stack) {
      return left(CacheFailure('Failed to load local vehicles', stack));
    }
  }

  static final _vehiclesRefreshLock = AsyncMutex();

  static Future<Result<List<Vehicle>>> _refreshVehiclesFromServer(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _vehiclesRefreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      try {
        // Fetch driver's profile first to get company_id
        final profileResponse = await client
            .from('profiles')
            .select('company_id')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse == null || profileResponse['company_id'] == null) {
          return right(<Vehicle>[]);
        }

        final companyId = profileResponse['company_id'] as String;

        // Fetch vehicles for the company
        final response = await client
            .from('vehicles')
            .select()
            .eq('company_id', companyId);

        final serverVehicles = (response as List).map((json) => Vehicle.fromJson(json)).toList();

        // Clear local cache and insert fresh
        await driverDatabase.delete(driverDatabase.vehicles).go();
        await driverDatabase.batch((batch) {
          for (final vehicle in serverVehicles) {
            batch.insert(
              driverDatabase.vehicles,
              _toVehicleCompanion(vehicle),
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        final dataList = await driverDatabase.select(driverDatabase.vehicles).get();
        return right(dataList.map((d) => _fromVehicleData(d)).toList());
      } catch (e, stack) {
        return left(UnexpectedFailure('Failed to sync vehicles from server', originalError: e, stackTrace: stack));
      }
    });
  }

  /// Watch maintenance schedules for a vehicle (reactive)
  static Stream<List<MaintenanceSchedule>> watchSchedules(
    String vehicleId, {
    SupabaseClient? supabaseClient,
  }) {
    final query = driverDatabase.select(driverDatabase.maintenanceSchedules)
      ..where((s) => s.vehicleId.equals(vehicleId) & s.isActive.equals(true));

    return query.watch().map((rows) => rows.map((d) => _fromScheduleData(d)).toList());
  }

  /// Get schedules for a vehicle, refreshing from server if online
  static Future<Result<List<MaintenanceSchedule>>> getSchedules(
    String vehicleId, {
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    try {
      final query = driverDatabase.select(driverDatabase.maintenanceSchedules)
        ..where((s) => s.vehicleId.equals(vehicleId) & s.isActive.equals(true));
      final dataList = await query.get();
      final cached = dataList.map((d) => _fromScheduleData(d)).toList();

      if (refresh && connectivityService.isOnline) {
        if (cached.isEmpty) {
          return await _refreshSchedulesFromServer(vehicleId, supabaseClient: client);
        }
        unawaited(_refreshSchedulesFromServer(vehicleId, supabaseClient: client));
      }

      return right(cached);
    } catch (e, stack) {
      return left(CacheFailure('Failed to load local maintenance schedules', stack));
    }
  }

  static final _schedulesRefreshLock = AsyncMutex();

  static Future<Result<List<MaintenanceSchedule>>> _refreshSchedulesFromServer(
    String vehicleId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _schedulesRefreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      try {
        final response = await client
            .from('maintenance_schedules')
            .select()
            .eq('vehicle_id', vehicleId)
            .eq('is_active', true);

        final serverSchedules = (response as List).map((json) => MaintenanceSchedule.fromJson(json)).toList();

        // Clear local cache for this vehicle and insert fresh
        await (driverDatabase.delete(driverDatabase.maintenanceSchedules)
              ..where((s) => s.vehicleId.equals(vehicleId)))
            .go();

        await driverDatabase.batch((batch) {
          for (final schedule in serverSchedules) {
            batch.insert(
              driverDatabase.maintenanceSchedules,
              _toScheduleCompanion(schedule),
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        final dataList = await (driverDatabase.select(driverDatabase.maintenanceSchedules)
              ..where((s) => s.vehicleId.equals(vehicleId) & s.isActive.equals(true)))
            .get();
        return right(dataList.map((d) => _fromScheduleData(d)).toList());
      } catch (e, stack) {
        return left(UnexpectedFailure('Failed to sync schedules from server', originalError: e, stackTrace: stack));
      }
    });
  }

  /// Watch maintenance records for a vehicle (reactive)
  static Stream<List<MaintenanceRecord>> watchRecords(
    String vehicleId, {
    SupabaseClient? supabaseClient,
  }) {
    final query = driverDatabase.select(driverDatabase.maintenanceRecords)
      ..where((r) => r.vehicleId.equals(vehicleId) & r.isDeleted.equals(false))
      ..orderBy([
        (r) => OrderingTerm(expression: r.performedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((d) => _fromRecordData(d)).toList());
  }

  /// Get maintenance records, refreshing from server if online
  static Future<Result<List<MaintenanceRecord>>> getRecords(
    String vehicleId, {
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    try {
      final query = driverDatabase.select(driverDatabase.maintenanceRecords)
        ..where((r) => r.vehicleId.equals(vehicleId) & r.isDeleted.equals(false))
        ..orderBy([
          (r) => OrderingTerm(expression: r.performedAt, mode: OrderingMode.desc),
        ]);
      final dataList = await query.get();
      final cached = dataList.map((d) => _fromRecordData(d)).toList();

      if (refresh && connectivityService.isOnline) {
        if (cached.isEmpty) {
          return await _refreshRecordsFromServer(vehicleId, supabaseClient: client);
        }
        unawaited(_refreshRecordsFromServer(vehicleId, supabaseClient: client));
      }

      return right(cached);
    } catch (e, stack) {
      return left(CacheFailure('Failed to load local maintenance records', stack));
    }
  }

  static final _recordsRefreshLock = AsyncMutex();

  static Future<Result<List<MaintenanceRecord>>> _refreshRecordsFromServer(
    String vehicleId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _recordsRefreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      try {
        final response = await client
            .from('maintenance_records')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('performed_at', ascending: false);

        final serverRecords = (response as List).map((json) => MaintenanceRecord.fromJson(json)).toList();

        final pendingCreateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'maintenance_records' && op.operationType == 'create')
            .map((op) => op.localId)
            .toSet();

        final pendingUpdateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'maintenance_records' && op.operationType == 'update')
            .map((op) => op.localId)
            .toSet();

        var deleteQuery = driverDatabase.delete(driverDatabase.maintenanceRecords)
          ..where((r) => r.vehicleId.equals(vehicleId));

        final idsToPreserve = {...pendingCreateIds, ...pendingUpdateIds};
        if (idsToPreserve.isNotEmpty) {
          deleteQuery = deleteQuery..where((r) => r.id.isNotIn(idsToPreserve.toList()));
        }
        await deleteQuery.go();

        await driverDatabase.batch((batch) {
          for (final record in serverRecords) {
            if (pendingUpdateIds.contains(record.id)) continue;
            batch.insert(
              driverDatabase.maintenanceRecords,
              _toRecordCompanion(record),
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        final dataList = await (driverDatabase.select(driverDatabase.maintenanceRecords)
              ..where((r) => r.vehicleId.equals(vehicleId) & r.isDeleted.equals(false))
              ..orderBy([
                (r) => OrderingTerm(expression: r.performedAt, mode: OrderingMode.desc),
              ]))
            .get();
        return right(dataList.map((d) => _fromRecordData(d)).toList());
      } catch (e, stack) {
        return left(UnexpectedFailure('Failed to sync maintenance records from server', originalError: e, stackTrace: stack));
      }
    });
  }

  /// Create a new maintenance record (offline-capable)
  static Future<Result<MaintenanceRecord>> createRecord(
    MaintenanceRecord record, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final localId = record.id.isEmpty ? _uuid.v4() : record.id;
      final localRecord = record.copyWith(
        id: localId,
        createdAt: DateTime.now(),
        createdBy: userId,
      );

      await driverDatabase
          .into(driverDatabase.maintenanceRecords)
          .insert(_toRecordCompanion(localRecord));

      // Update matching schedules' last performed info
      final matchingSchedules = await (driverDatabase.select(driverDatabase.maintenanceSchedules)
            ..where((s) => s.vehicleId.equals(localRecord.vehicleId) & s.serviceType.equals(localRecord.serviceType.name)))
          .get();
      for (final schedule in matchingSchedules) {
        await (driverDatabase.update(driverDatabase.maintenanceSchedules)
              ..where((s) => s.id.equals(schedule.id)))
            .write(MaintenanceSchedulesCompanion(
              lastOdometer: Value(localRecord.odometerAtService),
              lastPerformedAt: Value(localRecord.performedAt),
            ));
      }

      final payload = localRecord.toJson();
      await syncQueueService.enqueue(
        tableName: 'maintenance_records',
        operationType: 'create',
        payload: payload,
        localId: localId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(localRecord);
    } catch (e, stack) {
      return left(CacheFailure('Failed to log maintenance record locally', stack));
    }
  }

  /// Delete a maintenance record (offline-capable, soft delete)
  static Future<Result<Unit>> deleteRecord(
    String recordId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      await (driverDatabase.update(driverDatabase.maintenanceRecords)
            ..where((r) => r.id.equals(recordId)))
          .write(const MaintenanceRecordsCompanion(isDeleted: Value(true)));

      await syncQueueService.enqueue(
        tableName: 'maintenance_records',
        operationType: 'update',
        payload: {
          'id': recordId,
          'is_deleted': true,
        },
        localId: recordId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(unit);
    } catch (e, stack) {
      return left(CacheFailure('Failed to delete maintenance record locally', stack));
    }
  }

  // Domain Mappers

  static Vehicle _fromVehicleData(VehicleData data) {
    return Vehicle(
      id: data.id,
      truckNumber: data.truckNumber,
      vehicleType: data.vehicleType,
    );
  }

  static VehiclesCompanion _toVehicleCompanion(Vehicle v) {
    return VehiclesCompanion(
      id: Value(v.id),
      companyId: const Value(''),
      truckNumber: Value(v.truckNumber),
      vehicleType: Value(v.vehicleType ?? 'truck'),
      licensePlate: const Value(null),
      licenseProvince: const Value(null),
      vinNumber: const Value(''),
      dotNumber: const Value(null),
      insurancePolicy: const Value(null),
      terminalAddress: const Value(null),
      createdBy: const Value(null),
      createdAt: const Value(null),
      updatedAt: const Value(null),
    );
  }

  static MaintenanceSchedule _fromScheduleData(MaintenanceScheduleData data) {
    return MaintenanceSchedule(
      id: data.id,
      vehicleId: data.vehicleId,
      serviceType: _parseServiceType(data.serviceType),
      intervalMiles: data.intervalMiles,
      intervalDays: data.intervalDays,
      lastPerformedAt: data.lastPerformedAt,
      lastOdometer: data.lastOdometer,
      isActive: data.isActive,
      createdAt: data.createdAt,
    );
  }

  static MaintenanceSchedulesCompanion _toScheduleCompanion(MaintenanceSchedule s) {
    return MaintenanceSchedulesCompanion(
      id: Value(s.id),
      vehicleId: Value(s.vehicleId),
      serviceType: Value(s.serviceType.name),
      intervalMiles: Value(s.intervalMiles),
      intervalDays: Value(s.intervalDays),
      lastPerformedAt: Value(s.lastPerformedAt),
      lastOdometer: Value(s.lastOdometer),
      isActive: Value(s.isActive),
      createdAt: Value(s.createdAt),
    );
  }

  static MaintenanceRecord _fromRecordData(MaintenanceRecordData data) {
    return MaintenanceRecord(
      id: data.id,
      vehicleId: data.vehicleId,
      serviceType: _parseServiceType(data.serviceType),
      description: data.description,
      odometerAtService: data.odometerAtService,
      cost: data.cost,
      performedBy: data.performedBy,
      performedAt: data.performedAt,
      nextDueOdometer: data.nextDueOdometer,
      nextDueDate: data.nextDueDate,
      notes: data.notes,
      createdAt: data.createdAt,
      createdBy: data.createdBy,
    );
  }

  static MaintenanceRecordsCompanion _toRecordCompanion(MaintenanceRecord r) {
    return MaintenanceRecordsCompanion(
      id: Value(r.id),
      vehicleId: Value(r.vehicleId),
      serviceType: Value(r.serviceType.name),
      description: Value(r.description),
      odometerAtService: Value(r.odometerAtService),
      cost: Value(r.cost),
      performedBy: Value(r.performedBy),
      performedAt: Value(r.performedAt),
      nextDueOdometer: Value(r.nextDueOdometer),
      nextDueDate: Value(r.nextDueDate),
      notes: Value(r.notes),
      createdAt: Value(r.createdAt ?? DateTime.now()),
      createdBy: Value(r.createdBy),
      isSynced: const Value(false),
      isDeleted: const Value(false),
    );
  }

  static MaintenanceServiceType _parseServiceType(String type) {
    try {
      return MaintenanceServiceType.values.firstWhere((e) => e.name == type);
    } catch (_) {
      return MaintenanceServiceType.other;
    }
  }
}
