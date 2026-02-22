// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';
part 'document.g.dart';

/// Document type classification
enum DocumentType {
  @JsonValue('other')
  other,
  @JsonValue('contract')
  contract,
  @JsonValue('rate_confirmation')
  rateConfirmation,
  @JsonValue('bill_of_lading')
  billOfLading,
  @JsonValue('proof_of_delivery')
  proofOfDelivery,
  @JsonValue('invoice')
  invoice,
  @JsonValue('receipt')
  receipt,
  @JsonValue('insurance')
  insurance,
  @JsonValue('authority')
  authority,
  @JsonValue('w9')
  w9,
  @JsonValue('certificate')
  certificate,
  @JsonValue('inspection')
  inspection,
  @JsonValue('photo')
  photo,
  @JsonValue('citation')
  citation;

  String get displayName {
    switch (this) {
      case DocumentType.billOfLading:
        return 'Bill of Lading';
      case DocumentType.proofOfDelivery:
        return 'Proof of Delivery';
      case DocumentType.rateConfirmation:
        return 'Rate Confirmation';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }
}

/// Document model with polymorphic linking
@freezed
abstract class Document with _$Document {
  const factory Document({
    required String id,
    required String name,
    required String url,
    @JsonKey(name: 'document_type')
    @Default(DocumentType.other)
    DocumentType type,
    @JsonKey(name: 'customer_id') String? customerId,
    @JsonKey(name: 'load_id') String? loadId,
    @JsonKey(name: 'vehicle_id') String? vehicleId,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'company_id') String? companyId,
    @JsonKey(name: 'expiration_date') DateTime? expirationDate,
    @JsonKey(name: 'effective_date') DateTime? effectiveDate,
    @JsonKey(name: 'reference_number') String? referenceNumber,
    @Default([]) List<String> tags,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Document;

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);
}

/// Custom computed properties for [Document]
extension DocumentHelpers on Document {
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
