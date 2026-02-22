class Broker {
  final String id;
  final String name;
  final String mcNumber;
  final String dotNumber;
  final String phoneNumber;
  final String email;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String notes;

  Broker({
    required this.id,
    required this.name,
    required this.mcNumber,
    required this.dotNumber,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    required this.notes,
  });

  factory Broker.empty() {
    return Broker(
      id: '',
      name: '',
      mcNumber: '',
      dotNumber: '',
      phoneNumber: '',
      email: '',
      address: '',
      city: '',
      state: '',
      zipCode: '',
      country: '',
      notes: '',
    );
  }

  Broker copyWith({
    String? id,
    String? name,
    String? mcNumber,
    String? dotNumber,
    String? phoneNumber,
    String? email,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? notes,
  }) {
    return Broker(
      id: id ?? this.id,
      name: name ?? this.name,
      mcNumber: mcNumber ?? this.mcNumber,
      dotNumber: dotNumber ?? this.dotNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      notes: notes ?? this.notes,
    );
  }
}
