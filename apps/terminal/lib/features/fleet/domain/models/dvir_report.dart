// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dvir_report.freezed.dart';
part 'dvir_report.g.dart';

/// Type of DVIR inspection
enum DVIRInspectionType {
  @JsonValue('pre_trip')
  preTrip,
  @JsonValue('post_trip')
  postTrip,
}

/// Severity level for defects
enum DefectSeverity {
  @JsonValue('minor')
  minor,
  @JsonValue('major')
  major,
  @JsonValue('critical')
  critical,
}

/// DVIR inspection categories
enum DVIRCategory {
  brakes,
  tires,
  lights,
  mirrors,
  horn,
  wipers,
  steering,
  suspension,
  exhaust,
  coupling,
  fuel,
  electrical,
  body,
  emergency,
  other,
}

/// A single defect found during inspection
@freezed
abstract class DVIRDefect with _$DVIRDefect {
  const factory DVIRDefect({
    required DVIRCategory category,
    required String description,
    @Default(DefectSeverity.minor) DefectSeverity severity,
  }) = _DVIRDefect;

  factory DVIRDefect.fromJson(Map<String, dynamic> json) =>
      _$DVIRDefectFromJson(json);
}

/// Represents a Driver Vehicle Inspection Report (DVIR)
@freezed
abstract class DVIRReport with _$DVIRReport {
  const DVIRReport._();

  const factory DVIRReport({
    required String id,
    @JsonKey(name: 'vehicle_id') required String vehicleId,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'inspection_type')
    required DVIRInspectionType inspectionType,
    int? odometer,
    @JsonKey(name: 'defects_found') @Default(false) bool defectsFound,
    @Default([]) List<DVIRDefect> defects,
    @JsonKey(name: 'is_safe_to_operate') required bool isSafeToOperate,
    @JsonKey(name: 'driver_signature') String? driverSignature,
    @JsonKey(name: 'mechanic_signature') String? mechanicSignature,
    @JsonKey(name: 'corrected_at') DateTime? correctedAt,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // Joined fields from profiles
    @JsonKey(name: 'driver_name') String? driverName,
  }) = _DVIRReport;

  factory DVIRReport.fromJson(Map<String, dynamic> json) =>
      _$DVIRReportFromJson(json);

  /// Whether defects have been corrected
  bool get isCorrected => correctedAt != null;

  /// Whether this report requires mechanic attention
  bool get needsMechanicAttention =>
      defectsFound && !isSafeToOperate && !isCorrected;

  /// Count of critical defects
  int get criticalDefectCount =>
      defects.where((d) => d.severity == DefectSeverity.critical).length;
}

/// Extension for display-friendly names
extension DVIRInspectionTypeX on DVIRInspectionType {
  String get displayName {
    switch (this) {
      case DVIRInspectionType.preTrip:
        return 'Pre-Trip';
      case DVIRInspectionType.postTrip:
        return 'Post-Trip';
    }
  }
}

extension DVIRCategoryX on DVIRCategory {
  String get displayName {
    switch (this) {
      case DVIRCategory.brakes:
        return 'Brakes';
      case DVIRCategory.tires:
        return 'Tires & Wheels';
      case DVIRCategory.lights:
        return 'Lights & Reflectors';
      case DVIRCategory.mirrors:
        return 'Mirrors';
      case DVIRCategory.horn:
        return 'Horn';
      case DVIRCategory.wipers:
        return 'Windshield & Wipers';
      case DVIRCategory.steering:
        return 'Steering';
      case DVIRCategory.suspension:
        return 'Suspension';
      case DVIRCategory.exhaust:
        return 'Exhaust System';
      case DVIRCategory.coupling:
        return 'Coupling Devices';
      case DVIRCategory.fuel:
        return 'Fuel System';
      case DVIRCategory.electrical:
        return 'Electrical';
      case DVIRCategory.body:
        return 'Body & Frame';
      case DVIRCategory.emergency:
        return 'Emergency Equipment';
      case DVIRCategory.other:
        return 'Other';
    }
  }
}

extension DefectSeverityX on DefectSeverity {
  String get displayName {
    switch (this) {
      case DefectSeverity.minor:
        return 'Minor';
      case DefectSeverity.major:
        return 'Major';
      case DefectSeverity.critical:
        return 'Critical';
    }
  }
}
