enum CRMEntityType { broker, shipper, receiver, carrier }

class CRMEntity {
  final String id;
  final String name;
  final CRMEntityType type;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? stateProvince;
  final String? postalCode;
  final String? country;
  final String? paymentTerms;
  final String? notes;
  final Map<String, dynamic>
  metadata; // For table-specific flags like is_hazmat
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CRMEntity({
    required this.id,
    required this.name,
    required this.type,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.stateProvince,
    this.postalCode,
    this.country,
    this.paymentTerms,
    this.notes,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory CRMEntity.fromCustomerJson(Map<String, dynamic> json) {
    return CRMEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CRMEntityType
          .broker, // Usually 'customers' table in this app is brokers
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address_line1'] as String?,
      city: json['city'] as String?,
      stateProvince: json['state_province'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  factory CRMEntity.fromLocationJson(
    Map<String, dynamic> json,
    CRMEntityType type,
  ) {
    return CRMEntity(
      id: json['id'] as String,
      name: json['shipper_name'] ?? json['receiver_name'] ?? '',
      type: type,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      stateProvince: json['state_province'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      notes: json['notes'] as String?,
      metadata: json, // Store all flags
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
