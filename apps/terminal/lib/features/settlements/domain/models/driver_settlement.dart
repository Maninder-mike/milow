import 'settlement_item.dart';

enum SettlementStatus { draft, approved, paid, voided }

class DriverSettlement {
  final String id;
  final String driverId;
  final SettlementStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final double totalEarnings;
  final double totalDeductions;
  final double netPayout;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SettlementItem> items;

  DriverSettlement({
    required this.id,
    required this.driverId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netPayout,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory DriverSettlement.fromJson(
    Map<String, dynamic> json, [
    List<SettlementItem> items = const [],
  ]) {
    // Map 'void' in DB to 'voided' in enum to avoid keyword conflict if any,
    // though 'void' is allowed in enum but 'voided' is safer/clearer.
    final statusStr = json['status'] as String;
    final status = statusStr == 'void'
        ? SettlementStatus.voided
        : SettlementStatus.values.byName(statusStr);

    return DriverSettlement(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      status: status,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalEarnings: (json['total_earnings'] as num).toDouble(),
      totalDeductions: (json['total_deductions'] as num).toDouble(),
      netPayout: (json['net_payout'] as num).toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'status': status == SettlementStatus.voided ? 'void' : status.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_earnings': totalEarnings,
      'total_deductions': totalDeductions,
      'net_payout': netPayout,
      'notes': notes,
    };
  }
}
