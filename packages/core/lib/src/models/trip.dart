/// Model representing a trip entry
class Trip {
  final String? id;
  final String? userId;
  final String? vehicleId;
  final String tripNumber;
  final String truckNumber;
  final List<String> trailers;
  final DateTime tripDate;
  final List<String> pickupLocations;
  final List<String> deliveryLocations;
  final List<DateTime?> pickupTimes;
  final List<DateTime?> deliveryTimes;
  final List<bool> pickupCompleted;
  final List<bool> deliveryCompleted;
  final double? startOdometer;
  final double? endOdometer;
  final String distanceUnit; // 'mi' or 'km'
  final String? borderCrossing;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isEmptyLeg;

  Trip({
    required this.tripNumber,
    required this.truckNumber,
    required this.tripDate,
    required this.pickupLocations,
    required this.deliveryLocations,
    this.id,
    this.userId,
    this.vehicleId,
    this.trailers = const [],
    this.pickupTimes = const [],
    this.deliveryTimes = const [],
    this.pickupCompleted = const [],
    this.deliveryCompleted = const [],
    this.startOdometer,
    this.endOdometer,
    this.distanceUnit = 'mi',
    this.borderCrossing,
    this.notes,
    this.isEmptyLeg = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Calculate total distance if both odometer readings are available
  double? get totalDistance {
    if (startOdometer != null && endOdometer != null) {
      return endOdometer! - startOdometer!;
    }
    return null;
  }

  /// Get distance unit label
  String get distanceUnitLabel => distanceUnit == 'km' ? 'km' : 'mi';

  /// Check if all pickups are completed
  bool get allPickupsCompleted {
    if (pickupLocations.isEmpty) return true;
    if (pickupCompleted.isEmpty) return false;
    return pickupCompleted.every((c) => c);
  }

  /// Check if all deliveries are completed
  bool get allDeliveriesCompleted {
    if (deliveryLocations.isEmpty) return true;
    if (deliveryCompleted.isEmpty) return false;
    return deliveryCompleted.every((c) => c);
  }

  /// Check if trip is fully completed
  bool get isCompleted => allPickupsCompleted && allDeliveriesCompleted;

  /// Create Trip from JSON (Supabase response)
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      tripNumber: json['trip_number'] as String,
      truckNumber: json['truck_number'] as String,
      trailers:
          (json['trailers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tripDate: DateTime.parse(json['trip_date'] as String),
      pickupLocations: (json['pickup_locations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      deliveryLocations: (json['delivery_locations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      pickupTimes:
          (json['pickup_times'] as List<dynamic>?)
              ?.map((e) => e != null ? DateTime.parse(e as String) : null)
              .toList() ??
          [],
      deliveryTimes:
          (json['delivery_times'] as List<dynamic>?)
              ?.map((e) => e != null ? DateTime.parse(e as String) : null)
              .toList() ??
          [],
      pickupCompleted:
          (json['pickup_completed'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [],
      deliveryCompleted:
          (json['delivery_completed'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [],
      startOdometer: json['start_odometer'] != null
          ? (json['start_odometer'] as num).toDouble()
          : null,
      endOdometer: json['end_odometer'] != null
          ? (json['end_odometer'] as num).toDouble()
          : null,
      distanceUnit: json['distance_unit'] as String? ?? 'mi',
      borderCrossing: json['border_crossing'] as String?,
      notes: json['notes'] as String?,
      isEmptyLeg: json['is_empty_leg'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert Trip to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'trip_number': tripNumber,
      'truck_number': truckNumber,
      'trailers': trailers,
      'trip_date': tripDate.toIso8601String(),
      'pickup_locations': pickupLocations,
      'delivery_locations': deliveryLocations,
      'pickup_times': pickupTimes.map((t) => t?.toIso8601String()).toList(),
      'delivery_times': deliveryTimes.map((t) => t?.toIso8601String()).toList(),
      'pickup_completed': pickupCompleted,
      'delivery_completed': deliveryCompleted,
      'start_odometer': startOdometer,
      'end_odometer': endOdometer,
      'distance_unit': distanceUnit,
      'border_crossing': borderCrossing,
      'notes': notes,
      'is_empty_leg': isEmptyLeg,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Trip copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? tripNumber,
    String? truckNumber,
    List<String>? trailers,
    DateTime? tripDate,
    List<String>? pickupLocations,
    List<String>? deliveryLocations,
    List<DateTime?>? pickupTimes,
    List<DateTime?>? deliveryTimes,
    List<bool>? pickupCompleted,
    List<bool>? deliveryCompleted,
    double? startOdometer,
    double? endOdometer,
    String? distanceUnit,
    String? borderCrossing,
    String? notes,
    bool? isEmptyLeg,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      tripNumber: tripNumber ?? this.tripNumber,
      truckNumber: truckNumber ?? this.truckNumber,
      trailers: trailers ?? this.trailers,
      tripDate: tripDate ?? this.tripDate,
      pickupLocations: pickupLocations ?? this.pickupLocations,
      deliveryLocations: deliveryLocations ?? this.deliveryLocations,
      pickupTimes: pickupTimes ?? this.pickupTimes,
      deliveryTimes: deliveryTimes ?? this.deliveryTimes,
      pickupCompleted: pickupCompleted ?? this.pickupCompleted,
      deliveryCompleted: deliveryCompleted ?? this.deliveryCompleted,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      borderCrossing: borderCrossing ?? this.borderCrossing,
      notes: notes ?? this.notes,
      isEmptyLeg: isEmptyLeg ?? this.isEmptyLeg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, tripNumber: $tripNumber, truckNumber: $truckNumber, '
        'date: $tripDate, pickups: ${pickupLocations.length}, '
        'deliveries: ${deliveryLocations.length})';
  }
}
