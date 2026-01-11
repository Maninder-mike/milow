class Load {
  final String id;
  final String loadReference;
  final String? brokerId; // Foregin Key
  final String brokerName;
  final double rate;
  final String currency;
  final String goods;
  final double weight;
  final String quantity;
  final String weightUnit;
  final LoadLocation pickup;
  final LoadLocation delivery;
  final String status;
  final String loadNotes;
  final String companyNotes;
  final String? assignedDriverId;
  final String? assignedTruckId;
  final String? assignedTrailerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String tripNumber;
  final String? poNumber;

  Load({
    required this.id,
    required this.loadReference,
    this.brokerId,
    required this.brokerName,
    required this.rate,
    required this.currency,
    required this.goods,
    this.weight = 0.0,
    this.quantity = '',
    this.weightUnit = 'Lbs',
    required this.pickup,
    required this.delivery,
    required this.status,
    required this.loadNotes,
    required this.companyNotes,
    this.assignedDriverId,
    this.assignedTruckId,
    this.assignedTrailerId,
    this.createdAt,
    this.updatedAt,
    required this.tripNumber,
    this.poNumber,
  });

  factory Load.empty() {
    return Load(
      id: '',
      loadReference: '',
      brokerName: '',
      rate: 0.0,
      currency: 'CAD',
      goods: '',
      weight: 0.0,
      quantity: '',
      pickup: LoadLocation.empty().copyWith(date: DateTime.now()),
      delivery: LoadLocation.empty().copyWith(
        date: DateTime.now().add(const Duration(days: 1)),
      ),
      status: 'Pending',
      loadNotes: '',
      companyNotes: '',
      tripNumber: '',
      poNumber: null,
    );
  }

  Load copyWith({
    String? id,
    String? loadReference,
    String? brokerId,
    String? brokerName,
    double? rate,
    String? currency,
    String? goods,
    double? weight,
    String? quantity,
    String? weightUnit,
    LoadLocation? pickup,
    LoadLocation? delivery,
    String? status,
    String? loadNotes,
    String? companyNotes,
    String? assignedDriverId,
    String? assignedTruckId,
    String? assignedTrailerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tripNumber,
    String? poNumber,
  }) {
    return Load(
      id: id ?? this.id,
      loadReference: loadReference ?? this.loadReference,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      rate: rate ?? this.rate,
      currency: currency ?? this.currency,
      goods: goods ?? this.goods,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      weightUnit: weightUnit ?? this.weightUnit,
      pickup: pickup ?? this.pickup,
      delivery: delivery ?? this.delivery,
      status: status ?? this.status,
      loadNotes: loadNotes ?? this.loadNotes,
      companyNotes: companyNotes ?? this.companyNotes,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
      assignedTrailerId: assignedTrailerId ?? this.assignedTrailerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tripNumber: tripNumber ?? this.tripNumber,
      poNumber: poNumber ?? this.poNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'load_reference': loadReference,
      'broker_id': brokerId,
      'rate': rate,
      'currency': currency,
      'goods': goods,
      'weight': weight,
      'weight_unit': weightUnit,
      'quantity': quantity,
      'pickup_id': pickup.id, // Only save ID if mapped
      'pickup_date': pickup.date.toIso8601String(),
      'receiver_id': delivery.id, // Only save ID if mapped
      'delivery_date': delivery.date.toIso8601String(),
      'status': status,
      'load_notes': loadNotes,
      'company_notes': companyNotes,
      'assigned_driver_id': assignedDriverId,
      'assigned_truck_id': assignedTruckId,
      'assigned_trailer_id': assignedTrailerId,
      'trip_number': tripNumber,
      'po_number': poNumber,
    };
  }

  factory Load.fromJson(Map<String, dynamic> json) {
    // Handle joins manually or assume flattening logic elsewhere
    // This basic implementation assumes 'pickups' and 'receivers' relations are expanded
    final pickupData = json['pickups'] as Map<String, dynamic>?;
    final receiverData = json['receivers'] as Map<String, dynamic>?;
    final brokerData = json['customers'] as Map<String, dynamic>?;

    return Load(
      id: json['id'] as String,
      loadReference: json['load_reference'] as String? ?? '',
      brokerId: json['broker_id'] as String?,
      brokerName: brokerData?['name'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'CAD',
      goods: json['goods'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as String? ?? '',
      weightUnit: json['weight_unit'] as String? ?? 'Lbs',

      // Construct locations from joined data (fallback to basic or empty if not joined)
      pickup: pickupData != null
          ? LoadLocation.fromMap(pickupData, json['pickup_date'])
          : LoadLocation.empty().copyWith(id: json['pickup_id']),

      delivery: receiverData != null
          ? LoadLocation.fromMap(
              receiverData,
              json['delivery_date'],
            ) // delivery date usually in receiver table or load?
          // Wait, 'date' was in LoadLocation locally, but in DB where is date?
          // Pickups table has 'pickup_date'? No, 'pickups' table is likely the LOCATION master data.
          // The SCHEDULE date is on the load (or should be).
          // Actually, earlier `LoadLocation` had `date`. I need to handle that.
          : LoadLocation.empty().copyWith(id: json['receiver_id']),

      status: json['status'] as String? ?? 'Pending',
      loadNotes: json['load_notes'] as String? ?? '',
      companyNotes: json['company_notes'] as String? ?? '',
      assignedDriverId: json['assigned_driver_id'] as String?,
      assignedTruckId: json['assigned_truck_id'] as String?,
      assignedTrailerId: json['assigned_trailer_id'] as String?,
      tripNumber: json['trip_number'] as String? ?? '',
      poNumber: json['po_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

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
      companyName: map['shipper_name'] ?? map['receiver_name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state_province'] ?? '',
      zipCode: map['postal_code'] ?? '',
      contactName: map['contact_person'] ?? '',
      contactPhone: map['phone'] ?? '',
      contactFax: map['fax'] ?? '',
      // Date handling needs care - if not in location table, pass from load
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
}
