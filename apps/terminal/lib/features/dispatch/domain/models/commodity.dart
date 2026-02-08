import 'package:flutter/foundation.dart';

/// Freight Class for LTL rating (50-500 scale)
/// Lower class = higher density, lower rate
enum FreightClass {
  class50('50', 50),
  class55('55', 55),
  class60('60', 60),
  class65('65', 65),
  class70('70', 70),
  class77_5('77.5', 77.5),
  class85('85', 85),
  class92_5('92.5', 92.5),
  class100('100', 100),
  class110('110', 110),
  class125('125', 125),
  class150('150', 150),
  class175('175', 175),
  class200('200', 200),
  class250('250', 250),
  class300('300', 300),
  class400('400', 400),
  class500('500', 500);

  const FreightClass(this.label, this.value);
  final String label;
  final double value;

  /// Convert from database enum string (class_50 -> class50)
  static FreightClass? fromJson(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('class_', 'class').replaceAll('_', '');
    return FreightClass.values.cast<FreightClass?>().firstWhere(
      (e) => e?.name == normalized,
      orElse: () => null,
    );
  }

  String toJson() =>
      'class_${name.replaceAll('class', '').replaceAll('_', '_')}';
}

/// HAZMAT Packing Group (danger level)
enum PackingGroup {
  I('I - High Danger'),
  ii('II - Medium Danger'),
  iii('III - Low Danger');

  const PackingGroup(this.label);
  final String label;

  static PackingGroup? fromJson(String? value) {
    if (value == null) return null;
    return PackingGroup.values.cast<PackingGroup?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }
}

/// Temperature control requirements
enum TemperatureRequirement {
  none('No temp control'),
  frozen('Frozen (< 0°F / -18°C)'),
  refrigerated('Refrigerated (33-40°F / 1-4°C)'),
  cool('Cool (45-60°F / 7-15°C)'),
  heated('Heated (> 50°F / 10°C)');

  const TemperatureRequirement(this.label);
  final String label;

  static TemperatureRequirement fromJson(String? value) {
    if (value == null) return TemperatureRequirement.none;
    return TemperatureRequirement.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TemperatureRequirement.none,
    );
  }
}

/// Piece type for commodities
enum PieceType {
  pallet('Pallet'),
  box('Box'),
  crate('Crate'),
  drum('Drum'),
  roll('Roll'),
  bundle('Bundle'),
  bag('Bag'),
  container('Container'),
  skid('Skid'),
  tote('Tote'),
  other('Other');

  const PieceType(this.label);
  final String label;

  static PieceType fromJson(String? value) {
    if (value == null) return PieceType.pallet;
    return PieceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PieceType.other,
    );
  }
}

/// Commodity model for detailed freight tracking
/// Matches RoseRocket commodity object for TMS parity
@immutable
class Commodity {
  const Commodity({
    required this.id,
    required this.companyId,
    required this.description,
    this.loadId,
    this.stopId,
    this.sku,
    this.nmfcCode,
    this.freightClass,
    this.quantity = 1,
    this.pieceType = PieceType.pallet,
    this.weightPerUnit,
    this.totalWeight,
    this.weightUnit = 'lbs',
    this.length,
    this.width,
    this.height,
    this.dimensionUnit = 'in',
    this.volume,
    this.volumeUnit = 'cuft',
    this.linearFeet,
    this.isHazmat = false,
    this.hazmatClass,
    this.hazmatPackingGroup,
    this.unNumber,
    this.hazmatDescription,
    this.emergencyContact,
    this.isStackable = true,
    this.isFragile = false,
    this.temperatureRequirement = TemperatureRequirement.none,
    this.minTemp,
    this.maxTemp,
    this.tempUnit = 'F',
    this.declaredValue,
    this.currency = 'CAD',
    this.handlingInstructions,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String? loadId;
  final String? stopId;

  // Identification
  final String description;
  final String? sku;
  final String? nmfcCode;
  final FreightClass? freightClass;

  // Quantity
  final int quantity;
  final PieceType pieceType;

  // Weight
  final double? weightPerUnit;
  final double? totalWeight;
  final String weightUnit;

  // Dimensions
  final double? length;
  final double? width;
  final double? height;
  final String dimensionUnit;
  final double? volume;
  final String volumeUnit;
  final double? linearFeet;

  // HAZMAT
  final bool isHazmat;
  final String? hazmatClass;
  final PackingGroup? hazmatPackingGroup;
  final String? unNumber;
  final String? hazmatDescription;
  final String? emergencyContact;

  // Handling
  final bool isStackable;
  final bool isFragile;
  final TemperatureRequirement temperatureRequirement;
  final double? minTemp;
  final double? maxTemp;
  final String tempUnit;

  // Value
  final double? declaredValue;
  final String currency;

  // Notes
  final String? handlingInstructions;
  final String? notes;

  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Calculate dimensions string for display
  String? get dimensionsDisplay {
    if (length == null || width == null || height == null) return null;
    return '${length}x${width}x$height $dimensionUnit';
  }

  /// Calculate weight display
  String? get weightDisplay {
    if (totalWeight != null) return '$totalWeight $weightUnit';
    if (weightPerUnit != null) return '$weightPerUnit/$weightUnit per unit';
    return null;
  }

  /// Check if requires temperature control
  bool get requiresTempControl =>
      temperatureRequirement != TemperatureRequirement.none;

  factory Commodity.fromJson(Map<String, dynamic> json) {
    return Commodity(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      loadId: json['load_id'] as String?,
      stopId: json['stop_id'] as String?,
      description: json['description'] as String,
      sku: json['sku'] as String?,
      nmfcCode: json['nmfc_code'] as String?,
      freightClass: FreightClass.fromJson(json['freight_class'] as String?),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      pieceType: PieceType.fromJson(json['piece_type'] as String?),
      weightPerUnit: (json['weight_per_unit'] as num?)?.toDouble(),
      totalWeight: (json['total_weight'] as num?)?.toDouble(),
      weightUnit: json['weight_unit'] as String? ?? 'lbs',
      length: (json['length'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      dimensionUnit: json['dimension_unit'] as String? ?? 'in',
      volume: (json['volume'] as num?)?.toDouble(),
      volumeUnit: json['volume_unit'] as String? ?? 'cuft',
      linearFeet: (json['linear_feet'] as num?)?.toDouble(),
      isHazmat: json['is_hazmat'] as bool? ?? false,
      hazmatClass: json['hazmat_class'] as String?,
      hazmatPackingGroup: PackingGroup.fromJson(
        json['hazmat_packing_group'] as String?,
      ),
      unNumber: json['un_number'] as String?,
      hazmatDescription: json['hazmat_description'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      isStackable: json['is_stackable'] as bool? ?? true,
      isFragile: json['is_fragile'] as bool? ?? false,
      temperatureRequirement: TemperatureRequirement.fromJson(
        json['temperature_requirement'] as String?,
      ),
      minTemp: (json['min_temp'] as num?)?.toDouble(),
      maxTemp: (json['max_temp'] as num?)?.toDouble(),
      tempUnit: json['temp_unit'] as String? ?? 'F',
      declaredValue: (json['declared_value'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'CAD',
      handlingInstructions: json['handling_instructions'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      if (loadId != null) 'load_id': loadId,
      if (stopId != null) 'stop_id': stopId,
      'description': description,
      if (sku != null) 'sku': sku,
      if (nmfcCode != null) 'nmfc_code': nmfcCode,
      if (freightClass != null) 'freight_class': freightClass!.toJson(),
      'quantity': quantity,
      'piece_type': pieceType.name,
      if (weightPerUnit != null) 'weight_per_unit': weightPerUnit,
      if (totalWeight != null) 'total_weight': totalWeight,
      'weight_unit': weightUnit,
      if (length != null) 'length': length,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'dimension_unit': dimensionUnit,
      if (volume != null) 'volume': volume,
      'volume_unit': volumeUnit,
      if (linearFeet != null) 'linear_feet': linearFeet,
      'is_hazmat': isHazmat,
      if (hazmatClass != null) 'hazmat_class': hazmatClass,
      if (hazmatPackingGroup != null)
        'hazmat_packing_group': hazmatPackingGroup!.name,
      if (unNumber != null) 'un_number': unNumber,
      if (hazmatDescription != null) 'hazmat_description': hazmatDescription,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
      'is_stackable': isStackable,
      'is_fragile': isFragile,
      'temperature_requirement': temperatureRequirement.name,
      if (minTemp != null) 'min_temp': minTemp,
      if (maxTemp != null) 'max_temp': maxTemp,
      'temp_unit': tempUnit,
      if (declaredValue != null) 'declared_value': declaredValue,
      'currency': currency,
      if (handlingInstructions != null)
        'handling_instructions': handlingInstructions,
      if (notes != null) 'notes': notes,
    };
  }

  Commodity copyWith({
    String? id,
    String? companyId,
    String? loadId,
    String? stopId,
    String? description,
    String? sku,
    String? nmfcCode,
    FreightClass? freightClass,
    int? quantity,
    PieceType? pieceType,
    double? weightPerUnit,
    double? totalWeight,
    String? weightUnit,
    double? length,
    double? width,
    double? height,
    String? dimensionUnit,
    double? volume,
    String? volumeUnit,
    double? linearFeet,
    bool? isHazmat,
    String? hazmatClass,
    PackingGroup? hazmatPackingGroup,
    String? unNumber,
    String? hazmatDescription,
    String? emergencyContact,
    bool? isStackable,
    bool? isFragile,
    TemperatureRequirement? temperatureRequirement,
    double? minTemp,
    double? maxTemp,
    String? tempUnit,
    double? declaredValue,
    String? currency,
    String? handlingInstructions,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Commodity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      loadId: loadId ?? this.loadId,
      stopId: stopId ?? this.stopId,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      nmfcCode: nmfcCode ?? this.nmfcCode,
      freightClass: freightClass ?? this.freightClass,
      quantity: quantity ?? this.quantity,
      pieceType: pieceType ?? this.pieceType,
      weightPerUnit: weightPerUnit ?? this.weightPerUnit,
      totalWeight: totalWeight ?? this.totalWeight,
      weightUnit: weightUnit ?? this.weightUnit,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      dimensionUnit: dimensionUnit ?? this.dimensionUnit,
      volume: volume ?? this.volume,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      linearFeet: linearFeet ?? this.linearFeet,
      isHazmat: isHazmat ?? this.isHazmat,
      hazmatClass: hazmatClass ?? this.hazmatClass,
      hazmatPackingGroup: hazmatPackingGroup ?? this.hazmatPackingGroup,
      unNumber: unNumber ?? this.unNumber,
      hazmatDescription: hazmatDescription ?? this.hazmatDescription,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      isStackable: isStackable ?? this.isStackable,
      isFragile: isFragile ?? this.isFragile,
      temperatureRequirement:
          temperatureRequirement ?? this.temperatureRequirement,
      minTemp: minTemp ?? this.minTemp,
      maxTemp: maxTemp ?? this.maxTemp,
      tempUnit: tempUnit ?? this.tempUnit,
      declaredValue: declaredValue ?? this.declaredValue,
      currency: currency ?? this.currency,
      handlingInstructions: handlingInstructions ?? this.handlingInstructions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Commodity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
