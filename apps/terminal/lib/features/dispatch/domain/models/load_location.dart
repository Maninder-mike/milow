class LoadLocation {
  final String? id; // Database ID for pickups/receivers table
  final String companyName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String contactName;
  final String contactPhone;
  final String contactFax;
  final DateTime date;

  LoadLocation({
    this.id,
    required this.companyName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.contactName,
    required this.contactPhone,
    required this.contactFax,
    required this.date,
  });

  factory LoadLocation.empty() {
    return LoadLocation(
      companyName: '',
      address: '',
      city: '',
      state: '',
      zipCode: '',
      contactName: '',
      contactPhone: '',
      contactFax: '',
      date: DateTime.now(),
    );
  }

  factory LoadLocation.fromMap(Map<String, dynamic> map, [dynamic dateVal]) {
    return LoadLocation(
      id: map['id'],
      companyName:
          map['company_name'] ??
          map['shipper_name'] ??
          map['receiver_name'] ??
          '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? map['state_province'] ?? '',
      zipCode: map['zip_code'] ?? map['postal_code'] ?? '',
      contactName: map['contact_name'] ?? map['contact_person'] ?? '',
      contactPhone: map['contact_phone'] ?? map['phone'] ?? '',
      contactFax: map['contact_fax'] ?? map['fax'] ?? '',
      date: dateVal != null
          ? (dateVal is DateTime ? dateVal : DateTime.parse(dateVal.toString()))
          : DateTime.now(),
    );
  }

  LoadLocation copyWith({
    String? id,
    String? companyName,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? contactName,
    String? contactPhone,
    String? contactFax,
    DateTime? date,
  }) {
    return LoadLocation(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactFax: contactFax ?? this.contactFax,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'company_name': companyName,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_fax': contactFax,
      'date': date.toIso8601String(),
    };
  }
}
