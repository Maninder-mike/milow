import 'package:uuid/uuid.dart';

/// Status of an accessorial charge in the billing workflow
enum ChargeStatus {
  /// Charge created but not yet reviewed
  pending('Pending'),

  /// Charge approved by dispatcher/manager
  approved('Approved'),

  /// Charge included on invoice
  invoiced('Invoiced'),

  /// Charge paid by customer
  paid('Paid'),

  /// Charge disputed by customer/driver
  disputed('Disputed'),

  /// Charge was rejected and not billable
  rejected('Rejected');

  const ChargeStatus(this.displayName);
  final String displayName;

  static ChargeStatus fromString(String value) {
    return ChargeStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ChargeStatus.pending,
    );
  }

  String toJson() => name;
}

class AccessorialCharge {
  final String id;
  final String loadId;
  final String type; // Detention, Lumper, Layover, Other
  final double amount;
  final String currency;
  final String notes;
  final ChargeStatus status;
  final String? createdBy; // User ID who created the charge
  final String? approvedBy; // User ID who approved the charge
  final DateTime? createdAt;
  final DateTime? approvedAt;

  AccessorialCharge({
    required this.id,
    required this.loadId,
    required this.type,
    required this.amount,
    this.currency = 'CAD',
    this.notes = '',
    this.status = ChargeStatus.pending,
    this.createdBy,
    this.approvedBy,
    this.createdAt,
    this.approvedAt,
  });

  factory AccessorialCharge.create({
    required String loadId,
    required String type,
    required double amount,
    String currency = 'CAD',
    String notes = '',
    String? createdBy,
  }) {
    return AccessorialCharge(
      id: const Uuid().v4(),
      loadId: loadId,
      type: type,
      amount: amount,
      currency: currency,
      notes: notes,
      status: ChargeStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  factory AccessorialCharge.fromJson(Map<String, dynamic> json) {
    return AccessorialCharge(
      id: json['id'] as String,
      loadId: json['load_id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CAD',
      notes: json['notes'] as String? ?? '',
      status: json['status'] != null
          ? ChargeStatus.fromString(json['status'] as String)
          : ChargeStatus.pending,
      createdBy: json['created_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'load_id': loadId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'notes': notes,
      'status': status.toJson(),
      if (createdBy != null) 'created_by': createdBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
    };
  }

  AccessorialCharge copyWith({
    String? id,
    String? loadId,
    String? type,
    double? amount,
    String? currency,
    String? notes,
    ChargeStatus? status,
    String? createdBy,
    String? approvedBy,
    DateTime? createdAt,
    DateTime? approvedAt,
  }) {
    return AccessorialCharge(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  /// Approve this charge (transition to approved status)
  AccessorialCharge approve(String userId) {
    return copyWith(
      status: ChargeStatus.approved,
      approvedBy: userId,
      approvedAt: DateTime.now(),
    );
  }

  /// Check if charge can be edited
  bool get isEditable => status == ChargeStatus.pending;

  /// Check if charge is finalized
  bool get isFinalized =>
      status == ChargeStatus.invoiced || status == ChargeStatus.paid;
}
