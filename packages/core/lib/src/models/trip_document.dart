/// Document types for trip documents
enum TripDocumentType {
  ace,
  aci,
  billOfLading,
  commercialInvoice,
  complianceWSIP,
  complianceDriver,
  complianceAuto,
  complianceCargo,
  labels,
  bill,
  invoice,
  offloadManifest,
  preloadManifest,
  paps,
  payStub,
  proofOfPickup,
  proofOfDelivery,
  quoteSheet,
  rateConfirmation,
  ucc128,
  scaleTicket,
  fuelReceipt,
  other;

  String get value {
    switch (this) {
      case TripDocumentType.billOfLading:
        return 'bol';
      case TripDocumentType.proofOfDelivery:
        return 'pod';
      case TripDocumentType.commercialInvoice:
        return 'commercial_invoice';
      case TripDocumentType.rateConfirmation:
        return 'rate_confirmation';
      case TripDocumentType.proofOfPickup:
        return 'proof_of_pickup';
      case TripDocumentType.offloadManifest:
        return 'offload_manifest';
      case TripDocumentType.preloadManifest:
        return 'preload_manifest';
      case TripDocumentType.payStub:
        return 'pay_stub';
      case TripDocumentType.quoteSheet:
        return 'quote_sheet';
      case TripDocumentType.scaleTicket:
        return 'scale_ticket';
      case TripDocumentType.fuelReceipt:
        return 'fuel_receipt';
      case TripDocumentType.complianceWSIP:
        return 'compliance_wsip';
      case TripDocumentType.complianceDriver:
        return 'compliance_driver';
      case TripDocumentType.complianceAuto:
        return 'compliance_auto';
      case TripDocumentType.complianceCargo:
        return 'compliance_cargo';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case TripDocumentType.ace:
        return 'ACE Manifest';
      case TripDocumentType.aci:
        return 'ACI Manifest';
      case TripDocumentType.billOfLading:
        return 'Bill of Lading (BOL)';
      case TripDocumentType.commercialInvoice:
        return 'Commercial Invoice';
      case TripDocumentType.complianceWSIP:
        return 'Compliance - WSIP';
      case TripDocumentType.complianceDriver:
        return 'Compliance - Driver';
      case TripDocumentType.complianceAuto:
        return 'Compliance - Auto';
      case TripDocumentType.complianceCargo:
        return 'Compliance - Cargo';
      case TripDocumentType.labels:
        return 'Labels';
      case TripDocumentType.bill:
        return 'Bill';
      case TripDocumentType.invoice:
        return 'Invoice';
      case TripDocumentType.offloadManifest:
        return 'Offload Manifest';
      case TripDocumentType.preloadManifest:
        return 'Preload Manifest';
      case TripDocumentType.paps:
        return 'PAPS';
      case TripDocumentType.payStub:
        return 'Pay Stub';
      case TripDocumentType.proofOfPickup:
        return 'Proof of Pickup (POB)';
      case TripDocumentType.proofOfDelivery:
        return 'Proof of Delivery (POD)';
      case TripDocumentType.quoteSheet:
        return 'Quote Sheet';
      case TripDocumentType.rateConfirmation:
        return 'Rate Confirmation';
      case TripDocumentType.ucc128:
        return 'UCC-128 Labels';
      case TripDocumentType.scaleTicket:
        return 'Scale Ticket';
      case TripDocumentType.fuelReceipt:
        return 'Fuel Receipt';
      case TripDocumentType.other:
        return 'Other';
    }
  }

  static TripDocumentType fromValue(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    for (final type in TripDocumentType.values) {
      if (type.name.toLowerCase() == normalized ||
          type.value.toLowerCase() == normalized) {
        return type;
      }
    }
    // Specific mappings for common variations
    if (normalized == 'bol') return TripDocumentType.billOfLading;
    if (normalized == 'pod') return TripDocumentType.proofOfDelivery;
    if (normalized == 'carrier_confirmation') {
      return TripDocumentType.rateConfirmation;
    }

    return TripDocumentType.other;
  }
}

/// Stop type for document association
enum StopType {
  pickup,
  delivery;

  String get value => name;

  static StopType? fromValue(String? value) {
    if (value == 'pickup') return StopType.pickup;
    if (value == 'delivery') return StopType.delivery;
    return null;
  }
}

/// Model representing a trip document (BOL, POD, etc.)
class TripDocument {
  final String? id;
  final String tripId;
  final String? tripNumber;
  final String userId;
  final String? companyId;
  final TripDocumentType documentType;
  final String filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final StopType? stopType;
  final int? stopIndex;
  final String? notes;
  final String? description;
  final String? objectKey;
  final String? url;
  final bool isDeletable;
  final bool isSystemGenerated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TripDocument({
    required this.tripId,
    this.tripNumber,
    required this.documentType,
    required this.filePath,
    this.id,
    required this.userId,
    this.companyId,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.stopType,
    this.stopIndex,
    this.notes,
    this.description,
    this.objectKey,
    this.url,
    this.isDeletable = true,
    this.isSystemGenerated = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Create TripDocument from JSON (Supabase response)
  factory TripDocument.fromJson(Map<String, dynamic> json) {
    return TripDocument(
      id: json['id'] as String?,
      tripId: json['trip_id'] as String,
      tripNumber: json['trips'] != null
          ? json['trips']['trip_number'] as String?
          : json['trip_number'] as String?,
      userId: json['user_id'] as String,
      companyId: json['company_id'] as String?,
      documentType: TripDocumentType.fromValue(json['document_type'] as String),
      filePath: json['file_path'] as String,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      stopType: StopType.fromValue(json['stop_type'] as String?),
      stopIndex: json['stop_index'] as int?,
      notes: json['notes'] as String?,
      description: json['description'] as String?,
      objectKey: json['object_key'] as String?,
      url: json['url'] as String?,
      isDeletable: json['is_deletable'] as bool? ?? true,
      isSystemGenerated: json['is_system_generated'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert TripDocument to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'trip_id': tripId,
      if (tripNumber != null) 'trip_number': tripNumber,
      'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      'document_type': documentType.value,
      'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (stopType != null) 'stop_type': stopType!.value,
      if (stopIndex != null) 'stop_index': stopIndex,
      if (notes != null) 'notes': notes,
      if (description != null) 'description': description,
      if (objectKey != null) 'object_key': objectKey,
      if (url != null) 'url': url,
      'is_deletable': isDeletable,
      'is_system_generated': isSystemGenerated,
    };
  }

  /// Create a copy with updated fields
  TripDocument copyWith({
    String? id,
    String? tripId,
    String? tripNumber,
    String? userId,
    String? companyId,
    TripDocumentType? documentType,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    StopType? stopType,
    int? stopIndex,
    String? notes,
    String? description,
    String? objectKey,
    String? url,
    bool? isDeletable,
    bool? isSystemGenerated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripDocument(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      tripNumber: tripNumber ?? this.tripNumber,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      documentType: documentType ?? this.documentType,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      stopType: stopType ?? this.stopType,
      stopIndex: stopIndex ?? this.stopIndex,
      notes: notes ?? this.notes,
      description: description ?? this.description,
      objectKey: objectKey ?? this.objectKey,
      url: url ?? this.url,
      isDeletable: isDeletable ?? this.isDeletable,
      isSystemGenerated: isSystemGenerated ?? this.isSystemGenerated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TripDocument(id: $id, tripId: $tripId, type: ${documentType.label}, '
        'stopType: $stopType, stopIndex: $stopIndex)';
  }
}
