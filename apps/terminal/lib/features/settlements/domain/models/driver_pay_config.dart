enum DriverPayType { percentage, cpm, flat }

class RecurringDeduction {
  final String name;
  final double amount;
  final String frequency; // 'weekly', 'monthly', 'per_settlement'

  RecurringDeduction({
    required this.name,
    required this.amount,
    required this.frequency,
  });

  factory RecurringDeduction.fromJson(Map<String, dynamic> json) {
    return RecurringDeduction(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      frequency: json['frequency'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'frequency': frequency};
  }
}

class DriverPayConfig {
  final String id;
  final String driverId;
  final DriverPayType payType;
  final double payValue;
  final double? emptyCpm;
  final double? stopOffPay;
  final double? detentionPayPerHour;
  final double? layoverPay;
  final List<RecurringDeduction> recurringDeductions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DriverPayConfig({
    required this.id,
    required this.driverId,
    required this.payType,
    required this.payValue,
    this.emptyCpm,
    this.stopOffPay,
    this.detentionPayPerHour,
    this.layoverPay,
    this.recurringDeductions = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory DriverPayConfig.fromJson(Map<String, dynamic> json) {
    return DriverPayConfig(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      payType: DriverPayType.values.byName(json['pay_type'] as String),
      payValue: (json['pay_value'] as num).toDouble(),
      emptyCpm: json['empty_cpm'] != null
          ? (json['empty_cpm'] as num).toDouble()
          : null,
      stopOffPay: json['stop_off_pay'] != null
          ? (json['stop_off_pay'] as num).toDouble()
          : null,
      detentionPayPerHour: json['detention_pay_per_hour'] != null
          ? (json['detention_pay_per_hour'] as num).toDouble()
          : null,
      layoverPay: json['layover_pay'] != null
          ? (json['layover_pay'] as num).toDouble()
          : null,
      recurringDeductions: json['recurring_deductions'] != null
          ? (json['recurring_deductions'] as List)
                .map(
                  (e) => RecurringDeduction.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : const [],
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
      'empty_cpm': emptyCpm,
      'stop_off_pay': stopOffPay,
      'detention_pay_per_hour': detentionPayPerHour,
      'layover_pay': layoverPay,
      'recurring_deductions': recurringDeductions
          .map((e) => e.toJson())
          .toList(),
    };
  }
}
