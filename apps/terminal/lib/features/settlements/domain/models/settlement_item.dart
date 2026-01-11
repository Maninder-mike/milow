enum SettlementItemType {
  load_pay,
  fuel_deduction,
  bonus,
  reimbursement,
  other,
}

class SettlementItem {
  final String id;
  final String settlementId;
  final SettlementItemType type;
  final String description;
  final double amount;
  final String? referenceId;
  final DateTime? createdAt;

  SettlementItem({
    required this.id,
    required this.settlementId,
    required this.type,
    required this.description,
    required this.amount,
    this.referenceId,
    this.createdAt,
  });

  factory SettlementItem.fromJson(Map<String, dynamic> json) {
    return SettlementItem(
      id: json['id'] as String,
      settlementId: json['settlement_id'] as String,
      type: SettlementItemType.values.firstWhere((e) => e.name == json['type']),
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      referenceId: json['reference_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settlement_id': settlementId,
      'type': type.name,
      'description': description,
      'amount': amount,
      'reference_id': referenceId,
    };
  }
}
