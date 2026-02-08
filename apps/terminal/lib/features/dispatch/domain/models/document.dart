import 'package:flutter/foundation.dart';

/// Document type classification matching RoseRocket categories
enum DocumentType {
  other('Other'),
  contract('Contract'),
  rateConfirmation('Rate Confirmation', dbValue: 'rate_confirmation'),
  billOfLading('Bill of Lading', dbValue: 'bill_of_lading'),
  proofOfDelivery('Proof of Delivery', dbValue: 'proof_of_delivery'),
  invoice('Invoice'),
  receipt('Receipt'),
  insurance('Insurance'),
  authority('Authority'),
  w9('W9'),
  certificate('Certificate'),
  inspection('Inspection'),
  photo('Photo'),
  citation('Citation');

  const DocumentType(this.displayName, {this.dbValue});
  final String displayName;
  final String? dbValue;

  static DocumentType fromJson(String? value) {
    if (value == null) return DocumentType.other;
    return DocumentType.values.firstWhere(
      (t) =>
          t.name == value ||
          t.dbValue == value ||
          t.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentType.other,
    );
  }

  String toJson() => dbValue ?? name;
}

/// Document model with polymorphic linking to multiple objects
@immutable
class Document {
  final String id;
  final String name;
  final String url;
  final DocumentType type;

  // Polymorphic links
  final String? customerId;
  final String? loadId;
  final String? vehicleId;
  final String? driverId;
  final String? companyId;

  // Compliance & Details
  final DateTime? expirationDate;
  final DateTime? effectiveDate;
  final String? referenceNumber;
  final List<String> tags;

  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Document({
    required this.id,
    required this.name,
    required this.url,
    this.type = DocumentType.other,
    this.customerId,
    this.loadId,
    this.vehicleId,
    this.driverId,
    this.companyId,
    this.expirationDate,
    this.effectiveDate,
    this.referenceNumber,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      url: json['url'] as String? ?? '',
      type: DocumentType.fromJson(json['document_type'] as String?),
      customerId: json['customer_id'] as String?,
      loadId: json['load_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      driverId: json['driver_id'] as String?,
      companyId: json['company_id'] as String?,
      expirationDate: json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'] as String)
          : null,
      effectiveDate: json['effective_date'] != null
          ? DateTime.parse(json['effective_date'] as String)
          : null,
      referenceNumber: json['reference_number'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
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
      'name': name,
      'url': url,
      'document_type': type.toJson(),
      if (customerId != null) 'customer_id': customerId,
      if (loadId != null) 'load_id': loadId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (driverId != null) 'driver_id': driverId,
      if (companyId != null) 'company_id': companyId,
      if (expirationDate != null)
        'expiration_date': expirationDate!.toIso8601String(),
      if (effectiveDate != null)
        'effective_date': effectiveDate!.toIso8601String(),
      if (referenceNumber != null) 'reference_number': referenceNumber,
      'tags': tags,
    };
  }

  Document copyWith({
    String? id,
    String? name,
    String? url,
    DocumentType? type,
    String? customerId,
    String? loadId,
    String? vehicleId,
    String? driverId,
    String? companyId,
    DateTime? expirationDate,
    DateTime? effectiveDate,
    String? referenceNumber,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      customerId: customerId ?? this.customerId,
      loadId: loadId ?? this.loadId,
      vehicleId: vehicleId ?? this.vehicleId,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      expirationDate: expirationDate ?? this.expirationDate,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if document is linked to a specific load
  bool isLinkedToLoad(String loadId) => this.loadId == loadId;

  /// Check if compliance doc is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Check if document is a compliance document
  bool get isComplianceDocument =>
      type == DocumentType.insurance ||
      type == DocumentType.authority ||
      type == DocumentType.w9 ||
      type == DocumentType.certificate ||
      type == DocumentType.inspection;
}
