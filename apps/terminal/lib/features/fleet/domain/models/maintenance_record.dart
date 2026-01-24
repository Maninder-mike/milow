// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'maintenance_record.freezed.dart';
part 'maintenance_record.g.dart';

/// Service types for maintenance records
enum MaintenanceServiceType {
  @JsonValue('oil_change')
  oilChange,
  @JsonValue('tire_rotation')
  tireRotation,
  @JsonValue('tire_replacement')
  tireReplacement,
  @JsonValue('brake_service')
  brakeService,
  @JsonValue('brake_replacement')
  brakeReplacement,
  @JsonValue('transmission_service')
  transmissionService,
  @JsonValue('coolant_flush')
  coolantFlush,
  @JsonValue('air_filter')
  airFilter,
  @JsonValue('fuel_filter')
  fuelFilter,
  @JsonValue('def_filter')
  defFilter,
  @JsonValue('annual_inspection')
  annualInspection,
  @JsonValue('dot_inspection')
  dotInspection,
  @JsonValue('emissions_test')
  emissionsTest,
  @JsonValue('engine_repair')
  engineRepair,
  @JsonValue('electrical_repair')
  electricalRepair,
  @JsonValue('hvac_service')
  hvacService,
  @JsonValue('other')
  other,
}

/// Represents a single maintenance/service record for a vehicle
@freezed
abstract class MaintenanceRecord with _$MaintenanceRecord {
  const factory MaintenanceRecord({
    required String id,
    @JsonKey(name: 'vehicle_id') required String vehicleId,
    @JsonKey(name: 'service_type') required MaintenanceServiceType serviceType,
    String? description,
    @JsonKey(name: 'odometer_at_service') int? odometerAtService,
    double? cost,
    @JsonKey(name: 'performed_by') String? performedBy,
    @JsonKey(name: 'performed_at') required DateTime performedAt,
    @JsonKey(name: 'next_due_odometer') int? nextDueOdometer,
    @JsonKey(name: 'next_due_date') DateTime? nextDueDate,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
  }) = _MaintenanceRecord;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceRecordFromJson(json);
}

/// Extension for display-friendly names
extension MaintenanceServiceTypeX on MaintenanceServiceType {
  String get displayName {
    switch (this) {
      case MaintenanceServiceType.oilChange:
        return 'Oil Change';
      case MaintenanceServiceType.tireRotation:
        return 'Tire Rotation';
      case MaintenanceServiceType.tireReplacement:
        return 'Tire Replacement';
      case MaintenanceServiceType.brakeService:
        return 'Brake Service';
      case MaintenanceServiceType.brakeReplacement:
        return 'Brake Replacement';
      case MaintenanceServiceType.transmissionService:
        return 'Transmission Service';
      case MaintenanceServiceType.coolantFlush:
        return 'Coolant Flush';
      case MaintenanceServiceType.airFilter:
        return 'Air Filter';
      case MaintenanceServiceType.fuelFilter:
        return 'Fuel Filter';
      case MaintenanceServiceType.defFilter:
        return 'DEF Filter';
      case MaintenanceServiceType.annualInspection:
        return 'Annual Inspection';
      case MaintenanceServiceType.dotInspection:
        return 'DOT Inspection';
      case MaintenanceServiceType.emissionsTest:
        return 'Emissions Test';
      case MaintenanceServiceType.engineRepair:
        return 'Engine Repair';
      case MaintenanceServiceType.electricalRepair:
        return 'Electrical Repair';
      case MaintenanceServiceType.hvacService:
        return 'HVAC Service';
      case MaintenanceServiceType.other:
        return 'Other';
    }
  }

  /// Icon data suggestion for each type
  String get iconName {
    switch (this) {
      case MaintenanceServiceType.oilChange:
        return 'drop';
      case MaintenanceServiceType.tireRotation:
      case MaintenanceServiceType.tireReplacement:
        return 'circle';
      case MaintenanceServiceType.brakeService:
      case MaintenanceServiceType.brakeReplacement:
        return 'stop';
      case MaintenanceServiceType.annualInspection:
      case MaintenanceServiceType.dotInspection:
        return 'clipboard_check';
      default:
        return 'wrench';
    }
  }
}
