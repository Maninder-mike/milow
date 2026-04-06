/// Model representing a driver's real-time location
class DriverLocation {
  final String id;
  final String driverId;
  final String companyId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const DriverLocation({
    required this.id,
    required this.driverId,
    required this.companyId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.heading,
    this.speed,
    this.metadata,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      companyId: json['company_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      metadata: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'company_id': companyId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
