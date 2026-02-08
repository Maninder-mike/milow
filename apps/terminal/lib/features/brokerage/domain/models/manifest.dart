import 'package:flutter/foundation.dart';

enum ManifestStatus {
  draft('Draft'),
  offered('Offered'),
  assigned('Assigned'),
  inTransit('In Transit', dbValue: 'in_transit'),
  completed('Completed'),
  voided('Void', dbValue: 'void');

  final String label;
  final String? _dbValue;
  const ManifestStatus(this.label, {String? dbValue}) : _dbValue = dbValue;

  String get dbValue => _dbValue ?? name.toLowerCase();

  static ManifestStatus fromDbValue(String value) {
    return ManifestStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ManifestStatus.draft,
    );
  }
}

@immutable
class ManifestItem {
  final String id;
  final String manifestId;
  final String loadId;
  final int sequence;
  final DateTime createdAt;

  const ManifestItem({
    required this.id,
    required this.manifestId,
    required this.loadId,
    this.sequence = 0,
    required this.createdAt,
  });

  factory ManifestItem.fromJson(Map<String, dynamic> json) {
    return ManifestItem(
      id: json['id'],
      manifestId: json['manifest_id'],
      loadId: json['load_id'],
      sequence: json['sequence'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'manifest_id': manifestId,
      'load_id': loadId,
      'sequence': sequence,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class Manifest {
  final String id;
  final String companyId;
  final int manifestNumber;
  final String partnerId;
  final ManifestStatus status;
  final double agreedCost;
  final String currency;
  final DateTime? scheduledPickup;
  final DateTime? scheduledDelivery;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optional, populated if joined)
  final List<ManifestItem> items;

  const Manifest({
    required this.id,
    required this.companyId,
    required this.manifestNumber,
    required this.partnerId,
    this.status = ManifestStatus.draft,
    this.agreedCost = 0.0,
    this.currency = 'USD',
    this.scheduledPickup,
    this.scheduledDelivery,
    this.items = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Manifest copyWith({
    int? manifestNumber,
    String? partnerId,
    ManifestStatus? status,
    double? agreedCost,
    String? currency,
    DateTime? scheduledPickup,
    DateTime? scheduledDelivery,
    String? notes,
    List<ManifestItem>? items,
  }) {
    return Manifest(
      id: id,
      companyId: companyId,
      manifestNumber: manifestNumber ?? this.manifestNumber,
      partnerId: partnerId ?? this.partnerId,
      status: status ?? this.status,
      agreedCost: agreedCost ?? this.agreedCost,
      currency: currency ?? this.currency,
      scheduledPickup: scheduledPickup ?? this.scheduledPickup,
      scheduledDelivery: scheduledDelivery ?? this.scheduledDelivery,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'manifest_number': manifestNumber,
      'partner_id': partnerId,
      'status': status.dbValue,
      'agreed_cost': agreedCost,
      'currency': currency,
      'scheduled_pickup': scheduledPickup?.toIso8601String(),
      'scheduled_delivery': scheduledDelivery?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Manifest.fromJson(Map<String, dynamic> json) {
    var itemsList = <ManifestItem>[];
    if (json['manifest_items'] != null) {
      itemsList = (json['manifest_items'] as List)
          .map((i) => ManifestItem.fromJson(i))
          .toList();
    }

    return Manifest(
      id: json['id'],
      companyId: json['company_id'],
      manifestNumber: json['manifest_number'] ?? 0,
      partnerId: json['partner_id'],
      status: ManifestStatus.fromDbValue(json['status'] ?? 'draft'),
      agreedCost: (json['agreed_cost'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      scheduledPickup: json['scheduled_pickup'] != null
          ? DateTime.parse(json['scheduled_pickup'])
          : null,
      scheduledDelivery: json['scheduled_delivery'] != null
          ? DateTime.parse(json['scheduled_delivery'])
          : null,
      notes: json['notes'],
      items: itemsList,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
