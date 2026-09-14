/// Represents a single stop on a multi-stop load.
///
/// Section 15.A Safety Mandate:
/// Stops MUST maintain a 1-indexed [sequenceId] to enforce deterministic ordering.
class StopModel {
  const StopModel({
    required this.id,
    required this.loadId,
    required this.sequenceId,
    required this.stopType,
    required this.locationName,
    required this.address,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.scheduledAt,
    this.completedAt,
    this.notes,
  }) : assert(sequenceId >= 1, 'sequenceId must be 1-indexed (sequenceId >= 1)');

  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      id: json['id'] as String,
      loadId: json['load_id'] as String? ?? '',
      sequenceId: json['sequence_id'] as int? ?? 1,
      stopType: json['stop_type'] as String? ?? 'pickup',
      locationName: json['location_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String loadId;
  final int sequenceId;
  final String stopType; // 'pickup' | 'delivery' | 'intermediate'
  final String locationName;
  final String address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'load_id': loadId,
      'sequence_id': sequenceId,
      'stop_type': stopType,
      'location_name': locationName,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}
