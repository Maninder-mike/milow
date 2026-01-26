import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/network_provider.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';

part 'maintenance_repository.g.dart';

/// Repository for maintenance records and schedules
class MaintenanceRepository {
  final CoreNetworkClient _client;

  MaintenanceRepository(this._client);

  /// Fetch all maintenance records for a vehicle
  Future<Result<List<MaintenanceRecord>>> getServiceHistory(
    String vehicleId,
  ) async {
    return _client.query<List<MaintenanceRecord>>(() async {
      final data = await _client.supabase
          .from('maintenance_records')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('performed_at', ascending: false);

      return data.map((e) => MaintenanceRecord.fromJson(e)).toList();
    }, operationName: 'getServiceHistory');
  }

  /// Add a new maintenance record
  Future<Result<MaintenanceRecord>> addServiceRecord({
    required String vehicleId,
    required MaintenanceServiceType serviceType,
    required DateTime performedAt,
    String? description,
    int? odometerAtService,
    double? cost,
    String? performedBy,
    int? nextDueOdometer,
    DateTime? nextDueDate,
    String? notes,
  }) async {
    return _client.query<MaintenanceRecord>(() async {
      final currentUser = _client.supabase.auth.currentUser;

      final data = await _client.supabase
          .from('maintenance_records')
          .insert({
            'vehicle_id': vehicleId,
            'service_type': serviceType.name,
            'description': description,
            'odometer_at_service': odometerAtService,
            'cost': cost,
            'performed_by': performedBy,
            'performed_at': performedAt.toIso8601String(),
            'next_due_odometer': nextDueOdometer,
            'next_due_date': nextDueDate?.toIso8601String(),
            'notes': notes,
            'created_by': currentUser?.id,
          })
          .select()
          .single();

      // Update schedule if exists
      await _updateScheduleAfterService(
        vehicleId,
        serviceType,
        performedAt,
        odometerAtService,
      );

      return MaintenanceRecord.fromJson(data);
    }, operationName: 'addServiceRecord');
  }

  /// Update a maintenance record
  Future<Result<void>> updateServiceRecord(
    String id,
    Map<String, dynamic> updates,
  ) async {
    return _client.query<void>(() async {
      await _client.supabase
          .from('maintenance_records')
          .update(updates)
          .eq('id', id);
    }, operationName: 'updateServiceRecord');
  }

  /// Delete a maintenance record
  Future<Result<void>> deleteServiceRecord(String id) async {
    return _client.query<void>(() async {
      await _client.supabase.from('maintenance_records').delete().eq('id', id);
    }, operationName: 'deleteServiceRecord');
  }

  /// Get maintenance schedules for a vehicle
  Future<Result<List<MaintenanceSchedule>>> getSchedules(
    String vehicleId,
  ) async {
    return _client.query<List<MaintenanceSchedule>>(() async {
      final data = await _client.supabase
          .from('maintenance_schedules')
          .select()
          .eq('vehicle_id', vehicleId)
          .eq('is_active', true);

      return data.map((e) => MaintenanceSchedule.fromJson(e)).toList();
    }, operationName: 'getSchedules');
  }

  /// Create or update a maintenance schedule
  Future<Result<MaintenanceSchedule>> upsertSchedule({
    required String vehicleId,
    required MaintenanceServiceType serviceType,
    int? intervalMiles,
    int? intervalDays,
    DateTime? lastPerformedAt,
    int? lastOdometer,
  }) async {
    return _client.query<MaintenanceSchedule>(() async {
      final data = await _client.supabase
          .from('maintenance_schedules')
          .upsert({
            'vehicle_id': vehicleId,
            'service_type': serviceType.name,
            'interval_miles': intervalMiles,
            'interval_days': intervalDays,
            'last_performed_at': lastPerformedAt?.toIso8601String(),
            'last_odometer': lastOdometer,
            'is_active': true,
          }, onConflict: 'vehicle_id,service_type')
          .select()
          .single();

      return MaintenanceSchedule.fromJson(data);
    }, operationName: 'upsertSchedule');
  }

  /// Get all due maintenance alerts across the fleet
  Future<Result<List<({MaintenanceSchedule schedule, String vehicleNumber})>>>
  getFleetMaintenanceAlerts() async {
    return _client.query<
      List<({MaintenanceSchedule schedule, String vehicleNumber})>
    >(() async {
      final schedules = await _client.supabase
          .from('maintenance_schedules')
          .select('*, vehicles!inner(truck_number, odometer)')
          .eq('is_active', true);

      final alerts = <({MaintenanceSchedule schedule, String vehicleNumber})>[];

      for (final row in schedules) {
        final schedule = MaintenanceSchedule.fromJson(row);
        final vehicle = row['vehicles'] as Map<String, dynamic>;
        final currentOdometer = vehicle['odometer'] as int? ?? 0;
        final vehicleNumber = vehicle['truck_number'] as String? ?? 'Unknown';

        if (schedule.isDue(currentOdometer: currentOdometer)) {
          alerts.add((schedule: schedule, vehicleNumber: vehicleNumber));
        }
      }

      return alerts;
    }, operationName: 'getFleetMaintenanceAlerts');
  }

  /// Update schedule after a service is performed
  Future<void> _updateScheduleAfterService(
    String vehicleId,
    MaintenanceServiceType serviceType,
    DateTime performedAt,
    int? odometer,
  ) async {
    await _client.supabase
        .from('maintenance_schedules')
        .update({
          'last_performed_at': performedAt.toIso8601String(),
          'last_odometer': odometer,
        })
        .eq('vehicle_id', vehicleId)
        .eq('service_type', serviceType.name);
  }
}

@riverpod
MaintenanceRepository maintenanceRepository(Ref ref) {
  return MaintenanceRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Future<List<MaintenanceRecord>> maintenanceRecords(
  Ref ref,
  String vehicleId,
) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  final result = await repo.getServiceHistory(vehicleId);
  return result.fold((failure) => throw failure, (data) => data);
}

@riverpod
Future<List<MaintenanceSchedule>> maintenanceSchedules(
  Ref ref,
  String vehicleId,
) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  final result = await repo.getSchedules(vehicleId);
  return result.fold((failure) => throw failure, (data) => data);
}

@riverpod
Future<List<({MaintenanceSchedule schedule, String vehicleNumber})>>
fleetMaintenanceAlerts(Ref ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  final result = await repo.getFleetMaintenanceAlerts();
  return result.fold((failure) => throw failure, (data) => data);
}
