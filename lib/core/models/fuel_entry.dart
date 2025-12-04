/// Model representing a fuel entry
class FuelEntry {
  final String? id;
  final String? userId;
  final DateTime fuelDate;
  final String fuelType; // 'truck' or 'reefer'
  final String? truckNumber;
  final String? reeferNumber;
  final String? location;
  final double? odometerReading;
  final double? reeferHours;
  final double fuelQuantity;
  final double pricePerUnit;
  final String fuelUnit; // 'gal' or 'L'
  final String distanceUnit; // 'mi' or 'km'
  final String currency; // 'USD' or 'CAD'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FuelEntry({
    this.id,
    this.userId,
    required this.fuelDate,
    required this.fuelType,
    this.truckNumber,
    this.reeferNumber,
    this.location,
    this.odometerReading,
    this.reeferHours,
    required this.fuelQuantity,
    required this.pricePerUnit,
    this.fuelUnit = 'gal',
    this.distanceUnit = 'mi',
    this.currency = 'USD',
    this.createdAt,
    this.updatedAt,
  });

  /// Calculate total cost
  double get totalCost => fuelQuantity * pricePerUnit;

  /// Get fuel unit label
  String get fuelUnitLabel => fuelUnit == 'L' ? 'L' : 'gal';

  /// Get distance unit label
  String get distanceUnitLabel => distanceUnit == 'km' ? 'km' : 'mi';

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'CAD':
        return 'C\$';
      case 'USD':
      default:
        return '\$';
    }
  }

  /// Get formatted total cost with currency
  String get formattedTotalCost {
    return '$currencySymbol${totalCost.toStringAsFixed(2)}';
  }

  /// Get formatted price per unit with currency and unit
  String get formattedPricePerUnit {
    return '$currencySymbol${pricePerUnit.toStringAsFixed(3)}/$fuelUnitLabel';
  }

  /// Check if this is a truck fuel entry
  bool get isTruckFuel => fuelType == 'truck';

  /// Check if this is a reefer fuel entry
  bool get isReeferFuel => fuelType == 'reefer';

  /// Create FuelEntry from JSON (Supabase response)
  factory FuelEntry.fromJson(Map<String, dynamic> json) {
    return FuelEntry(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      fuelDate: DateTime.parse(json['fuel_date'] as String),
      fuelType: json['fuel_type'] as String,
      truckNumber: json['truck_number'] as String?,
      reeferNumber: json['reefer_number'] as String?,
      location: json['location'] as String?,
      odometerReading: json['odometer_reading'] != null
          ? (json['odometer_reading'] as num).toDouble()
          : null,
      reeferHours: json['reefer_hours'] != null
          ? (json['reefer_hours'] as num).toDouble()
          : null,
      fuelQuantity: (json['fuel_quantity'] as num).toDouble(),
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      fuelUnit: json['fuel_unit'] as String? ?? 'gal',
      distanceUnit: json['distance_unit'] as String? ?? 'mi',
      currency: json['currency'] as String? ?? 'USD',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert FuelEntry to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'fuel_date': fuelDate.toIso8601String(),
      'fuel_type': fuelType,
      'truck_number': truckNumber,
      'reefer_number': reeferNumber,
      'location': location,
      'odometer_reading': odometerReading,
      'reefer_hours': reeferHours,
      'fuel_quantity': fuelQuantity,
      'price_per_unit': pricePerUnit,
      'fuel_unit': fuelUnit,
      'distance_unit': distanceUnit,
      'currency': currency,
    };
  }

  /// Create a copy with updated fields
  FuelEntry copyWith({
    String? id,
    String? userId,
    DateTime? fuelDate,
    String? fuelType,
    String? truckNumber,
    String? reeferNumber,
    String? location,
    double? odometerReading,
    double? reeferHours,
    double? fuelQuantity,
    double? pricePerUnit,
    String? fuelUnit,
    String? distanceUnit,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FuelEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fuelDate: fuelDate ?? this.fuelDate,
      fuelType: fuelType ?? this.fuelType,
      truckNumber: truckNumber ?? this.truckNumber,
      reeferNumber: reeferNumber ?? this.reeferNumber,
      location: location ?? this.location,
      odometerReading: odometerReading ?? this.odometerReading,
      reeferHours: reeferHours ?? this.reeferHours,
      fuelQuantity: fuelQuantity ?? this.fuelQuantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      fuelUnit: fuelUnit ?? this.fuelUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FuelEntry(id: $id, type: $fuelType, quantity: $fuelQuantity $fuelUnitLabel, '
        'price: $formattedPricePerUnit, total: $formattedTotalCost)';
  }
}
