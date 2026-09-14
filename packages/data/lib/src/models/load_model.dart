import 'package:milow_data/src/models/stop_model.dart';

/// Represents a dispatch load.
///
/// Section 15.A Mandate: All Loads MUST support `List<Stop>`.
class LoadModel {
  const LoadModel({
    required this.id,
    required this.companyId,
    required this.loadNumber,
    required this.status,
    required this.stops,
    this.driverId,
    this.vehicleId,
    this.rate,
    this.createdAt,
    this.updatedAt,
  }) : assert(stops.length >= 2, 'Load must contain at least 2 stops (pickup & delivery)');

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? [];
    final parsedStops = rawStops
        .map((s) => StopModel.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sequenceId.compareTo(b.sequenceId));

    return LoadModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String? ?? '',
      loadNumber: json['load_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      stops: parsedStops,
      driverId: json['driver_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      rate: (json['rate'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String companyId;
  final String loadNumber;
  final String status; // 'pending' | 'assigned' | 'in_transit' | 'completed' | 'cancelled'
  final List<StopModel> stops;
  final String? driverId;
  final String? vehicleId;
  final double? rate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'load_number': loadNumber,
      'status': status,
      'stops': stops.map((s) => s.toJson()).toList(),
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'rate': rate,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
