// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import 'maintenance_record.dart';

part 'maintenance_schedule.freezed.dart';
part 'maintenance_schedule.g.dart';

/// Represents a recurring maintenance schedule for proactive alerts
@freezed
abstract class MaintenanceSchedule with _$MaintenanceSchedule {
  const MaintenanceSchedule._();

  const factory MaintenanceSchedule({
    required String id,
    @JsonKey(name: 'vehicle_id') required String vehicleId,
    @JsonKey(name: 'service_type') required MaintenanceServiceType serviceType,
    @JsonKey(name: 'interval_miles') int? intervalMiles,
    @JsonKey(name: 'interval_days') int? intervalDays,
    @JsonKey(name: 'last_performed_at') DateTime? lastPerformedAt,
    @JsonKey(name: 'last_odometer') int? lastOdometer,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _MaintenanceSchedule;

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceScheduleFromJson(json);

  /// Check if maintenance is due based on current odometer and date
  bool isDue({required int currentOdometer, DateTime? currentDate}) {
    currentDate ??= DateTime.now();

    // Check mileage-based due
    if (intervalMiles != null && lastOdometer != null) {
      final milesSinceService = currentOdometer - lastOdometer!;
      if (milesSinceService >= intervalMiles!) {
        return true;
      }
    }

    // Check time-based due
    if (intervalDays != null && lastPerformedAt != null) {
      final daysSinceService = currentDate.difference(lastPerformedAt!).inDays;
      if (daysSinceService >= intervalDays!) {
        return true;
      }
    }

    return false;
  }

  /// Get days or miles until next service
  String getNextDueInfo({required int currentOdometer, DateTime? currentDate}) {
    currentDate ??= DateTime.now();
    final parts = <String>[];

    if (intervalMiles != null && lastOdometer != null) {
      final milesRemaining = (lastOdometer! + intervalMiles!) - currentOdometer;
      if (milesRemaining > 0) {
        parts.add('$milesRemaining mi');
      } else {
        parts.add('${milesRemaining.abs()} mi overdue');
      }
    }

    if (intervalDays != null && lastPerformedAt != null) {
      final nextDue = lastPerformedAt!.add(Duration(days: intervalDays!));
      final daysRemaining = nextDue.difference(currentDate).inDays;
      if (daysRemaining > 0) {
        parts.add('$daysRemaining days');
      } else {
        parts.add('${daysRemaining.abs()} days overdue');
      }
    }

    return parts.isEmpty ? 'Not scheduled' : parts.join(' or ');
  }
}
