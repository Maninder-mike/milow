// Copyright (c) 2024 Milow. All rights reserved.

/// A data model representing a vehicle in the fleet.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.truckNumber,
    this.vehicleType,
  });

  /// Creates a [Vehicle] from a JSON map.
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      truckNumber: json['truck_number'] as String,
      vehicleType: json['vehicle_type'] as String?,
    );
  }

  /// The unique identifier for the vehicle.
  final String id;

  /// The truck number (e.g., "TRK-001").
  final String truckNumber;

  /// The type of vehicle (e.g., "truck", "van").
  final String? vehicleType;

  /// Converts this [Vehicle] to a JSON map.
  Map<String, dynamic> toJson() {
    return {'id': id, 'truck_number': truckNumber, 'vehicle_type': vehicleType};
  }

  @override
  String toString() => 'Vehicle(id: $id, truckNumber: $truckNumber)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle &&
        other.id == id &&
        other.truckNumber == truckNumber &&
        other.vehicleType == vehicleType;
  }

  @override
  int get hashCode => Object.hash(id, truckNumber, vehicleType);
}
