enum DriverPayType { percentage, cpm, flat }

class DriverPayConfig {
  final String id;
  final String driverId;
  final DriverPayType payType;
  final double payValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DriverPayConfig({
    required this.id,
    required this.driverId,
    required this.payType,
    required this.payValue,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverPayConfig.fromJson(Map<String, dynamic> json) {
    return DriverPayConfig(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      payType: DriverPayType.values.byName(json['pay_type'] as String),
      payValue: (json['pay_value'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'pay_type': payType.name,
      'pay_value': payValue,
    };
  }
}
