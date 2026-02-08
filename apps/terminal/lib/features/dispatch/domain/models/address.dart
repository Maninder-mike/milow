import 'package:uuid/uuid.dart';

/// Address type classification for RoseRocket parity
enum AddressType {
  customer('Customer'),
  shipper('Shipper'),
  receiver('Receiver'),
  warehouse('Warehouse'),
  terminal('Terminal'),
  other('Other');

  const AddressType(this.displayName);
  final String displayName;

  static AddressType fromString(String? value) {
    if (value == null) return AddressType.other;
    return AddressType.values.firstWhere(
      (t) => t.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AddressType.other,
    );
  }

  String toJson() => name;
}

/// Normalized address model for reuse across loads, customers, and partners
class Address {
  final String id;
  final String? companyId;
  final String? name;
  final String streetLine1;
  final String? streetLine2;
  final String city;
  final String stateProvince;
  final String postalCode;
  final String country;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactFax;
  final double? latitude;
  final double? longitude;
  final AddressType addressType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  Address({
    required this.id,
    this.companyId,
    this.name,
    required this.streetLine1,
    this.streetLine2,
    required this.city,
    required this.stateProvince,
    required this.postalCode,
    this.country = 'CA',
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.contactFax,
    this.latitude,
    this.longitude,
    this.addressType = AddressType.other,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  /// Create a new address with generated UUID
  factory Address.create({
    String? companyId,
    String? name,
    required String streetLine1,
    String? streetLine2,
    required String city,
    required String stateProvince,
    required String postalCode,
    String country = 'CA',
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? contactFax,
    double? latitude,
    double? longitude,
    AddressType addressType = AddressType.other,
  }) {
    return Address(
      id: const Uuid().v4(),
      companyId: companyId,
      name: name,
      streetLine1: streetLine1,
      streetLine2: streetLine2,
      city: city,
      stateProvince: stateProvince,
      postalCode: postalCode,
      country: country,
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      contactFax: contactFax,
      latitude: latitude,
      longitude: longitude,
      addressType: addressType,
      createdAt: DateTime.now(),
      isActive: true,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      name: json['name'] as String?,
      streetLine1: json['street_line_1'] as String,
      streetLine2: json['street_line_2'] as String?,
      city: json['city'] as String,
      stateProvince: json['state_province'] as String,
      postalCode: json['postal_code'] as String,
      country: json['country'] as String? ?? 'CA',
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactFax: json['contact_fax'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressType: AddressType.fromString(json['address_type'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      'street_line_1': streetLine1,
      if (streetLine2 != null) 'street_line_2': streetLine2,
      'city': city,
      'state_province': stateProvince,
      'postal_code': postalCode,
      'country': country,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactFax != null) 'contact_fax': contactFax,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'address_type': addressType.toJson(),
      'is_active': isActive,
    };
  }

  Address copyWith({
    String? id,
    String? companyId,
    String? name,
    String? streetLine1,
    String? streetLine2,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? contactFax,
    double? latitude,
    double? longitude,
    AddressType? addressType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Address(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      streetLine1: streetLine1 ?? this.streetLine1,
      streetLine2: streetLine2 ?? this.streetLine2,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      contactFax: contactFax ?? this.contactFax,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressType: addressType ?? this.addressType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get formatted full address string
  String get fullAddress {
    final parts = <String>[streetLine1];
    if (streetLine2 != null && streetLine2!.isNotEmpty) {
      parts.add(streetLine2!);
    }
    parts.add('$city, $stateProvince $postalCode');
    if (country != 'CA' && country != 'US') {
      parts.add(country);
    }
    return parts.join('\n');
  }

  /// Get single-line address for display
  String get singleLineAddress => '$city, $stateProvince $postalCode';

  /// Check if address has geo coordinates
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Convert to LoadLocation for backward compatibility
  Map<String, dynamic> toLoadLocationMap(DateTime date) {
    return {
      'id': id,
      'company_name': name ?? '',
      'address': streetLine1 + (streetLine2 != null ? ', $streetLine2' : ''),
      'city': city,
      'state': stateProvince,
      'zip_code': postalCode,
      'contact_name': contactName ?? '',
      'contact_phone': contactPhone ?? '',
      'contact_fax': contactFax ?? '',
      'date': date.toIso8601String(),
    };
  }
}
