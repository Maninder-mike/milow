class Load {
  final String id;
  final String loadReference;
  final String brokerName;
  final double rate;
  final String currency;
  final String goods;
  final LoadLocation pickup;
  final LoadLocation delivery;
  final String status; // 'Pending', 'Active', 'Delivered'
  final String loadNotes;
  final String companyNotes;
  final String? assignedDriverId;
  final String? assignedTruckId;

  Load({
    required this.id,
    required this.loadReference,
    required this.brokerName,
    required this.rate,
    required this.currency,
    required this.goods,
    required this.pickup,
    required this.delivery,
    required this.status,
    required this.loadNotes,
    required this.companyNotes,
    this.assignedDriverId,
    this.assignedTruckId,
  });

  // Factory for empty/new load
  factory Load.empty() {
    return Load(
      id: '',
      loadReference: '',
      brokerName: '',
      rate: 0.0,
      currency: 'CAD',
      goods: '',
      pickup: LoadLocation.empty().copyWith(date: DateTime.now()),
      delivery: LoadLocation.empty().copyWith(
        date: DateTime.now().add(const Duration(days: 1)),
      ),
      status: 'Pending',
      loadNotes: '',
      companyNotes: '',
    );
  }

  Load copyWith({
    String? id,
    String? loadReference,
    String? brokerName,
    double? rate,
    String? currency,
    String? goods,
    LoadLocation? pickup,
    LoadLocation? delivery,
    String? status,
    String? loadNotes,
    String? companyNotes,
    String? assignedDriverId,
    String? assignedTruckId,
  }) {
    return Load(
      id: id ?? this.id,
      loadReference: loadReference ?? this.loadReference,
      brokerName: brokerName ?? this.brokerName,
      rate: rate ?? this.rate,
      currency: currency ?? this.currency,
      goods: goods ?? this.goods,
      pickup: pickup ?? this.pickup,
      delivery: delivery ?? this.delivery,
      status: status ?? this.status,
      loadNotes: loadNotes ?? this.loadNotes,
      companyNotes: companyNotes ?? this.companyNotes,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
    );
  }
}

class LoadLocation {
  final String companyName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String contactName;
  final String contactPhone;
  final String contactFax;
  final DateTime
  date; // Keeping date coupled with location makes sense for a "Stop"

  LoadLocation({
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

  LoadLocation copyWith({
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
