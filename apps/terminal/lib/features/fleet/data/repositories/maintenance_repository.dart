import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';

part 'maintenance_repository.g.dart';

/// Repository for maintenance records and schedules
class MaintenanceRepository {
  final SupabaseClient _client;

  MaintenanceRepository(this._client);

  /// Fetch all maintenance records for a vehicle
  Future<List<MaintenanceRecord>> getServiceHistory(String vehicleId) async {
    final data = await _client
        .from('maintenance_records')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('performed_at', ascending: false);

    return data.map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  /// Add a new maintenance record
  Future<MaintenanceRecord> addServiceRecord({
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
    final currentUser = _client.auth.currentUser;

    final data = await _client
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
  }

  /// Update a maintenance record
  Future<void> updateServiceRecord(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('maintenance_records').update(updates).eq('id', id);
  }

  /// Delete a maintenance record
  Future<void> deleteServiceRecord(String id) async {
    await _client.from('maintenance_records').delete().eq('id', id);
  }

  /// Get maintenance schedules for a vehicle
  Future<List<MaintenanceSchedule>> getSchedules(String vehicleId) async {
    final data = await _client
        .from('maintenance_schedules')
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('is_active', true);

    return data.map((e) => MaintenanceSchedule.fromJson(e)).toList();
  }

  /// Create or update a maintenance schedule
  Future<MaintenanceSchedule> upsertSchedule({
    required String vehicleId,
    required MaintenanceServiceType serviceType,
    int? intervalMiles,
    int? intervalDays,
    DateTime? lastPerformedAt,
    int? lastOdometer,
  }) async {
    final data = await _client
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
  }

  /// Get all due maintenance alerts across the fleet
  Future<List<({MaintenanceSchedule schedule, String vehicleNumber})>>
  getFleetMaintenanceAlerts() async {
    final schedules = await _client
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
  }

  /// Update schedule after a service is performed
  Future<void> _updateScheduleAfterService(
    String vehicleId,
    MaintenanceServiceType serviceType,
    DateTime performedAt,
    int? odometer,
  ) async {
    await _client
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
  return MaintenanceRepository(ref.read(supabaseClientProvider));
}

@riverpod
Future<List<MaintenanceRecord>> maintenanceRecords(
  Ref ref,
  String vehicleId,
) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getServiceHistory(vehicleId);
}

@riverpod
Future<List<MaintenanceSchedule>> maintenanceSchedules(
  Ref ref,
  String vehicleId,
) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getSchedules(vehicleId);
}

@riverpod
Future<List<({MaintenanceSchedule schedule, String vehicleNumber})>>
fleetMaintenanceAlerts(Ref ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getFleetMaintenanceAlerts();
}
