import 'package:flutter/foundation.dart';

enum PartnerStatus {
  onboarding('Onboarding'),
  active('Active'),
  inactive('Inactive'),
  rejected('Rejected');

  final String label;
  const PartnerStatus(this.label);

  String get dbValue => name.toLowerCase();

  static PartnerStatus fromDbValue(String value) {
    return PartnerStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => PartnerStatus.onboarding,
    );
  }
}

enum SafetyRating {
  satisfactory('Satisfactory'),
  conditional('Conditional'),
  unsatisfactory('Unsatisfactory'),
  notRated('Not Rated', dbValue: 'not_rated');

  final String label;
  final String? _dbValue;
  const SafetyRating(this.label, {String? dbValue}) : _dbValue = dbValue;

  String get dbValue => _dbValue ?? name.toLowerCase();

  static SafetyRating fromDbValue(String value) {
    return SafetyRating.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => SafetyRating.notRated,
    );
  }
}

@immutable
class Partner {
  final String id;
  final String companyId;
  final String name;
  final String? mcNumber;
  final String? dotNumber;
  final String? scac;
  final PartnerStatus status;
  final String? addressId;
  final String? primaryContactId;
  final DateTime? insuranceExpiration;
  final SafetyRating? safetyRating;
  final String? notes;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Partner({
    required this.id,
    required this.companyId,
    required this.name,
    this.mcNumber,
    this.dotNumber,
    this.scac,
    this.status = PartnerStatus.onboarding,
    this.addressId,
    this.primaryContactId,
    this.insuranceExpiration,
    this.safetyRating,
    this.notes,
    this.currency = 'USD',
    required this.createdAt,
    required this.updatedAt,
  });

  Partner copyWith({
    String? name,
    String? mcNumber,
    String? dotNumber,
    String? scac,
    PartnerStatus? status,
    String? addressId,
    String? primaryContactId,
    DateTime? insuranceExpiration,
    SafetyRating? safetyRating,
    String? notes,
    String? currency,
  }) {
    return Partner(
      id: id,
      companyId: companyId,
      name: name ?? this.name,
      mcNumber: mcNumber ?? this.mcNumber,
      dotNumber: dotNumber ?? this.dotNumber,
      scac: scac ?? this.scac,
      status: status ?? this.status,
      addressId: addressId ?? this.addressId,
      primaryContactId: primaryContactId ?? this.primaryContactId,
      insuranceExpiration: insuranceExpiration ?? this.insuranceExpiration,
      safetyRating: safetyRating ?? this.safetyRating,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'mc_number': mcNumber,
      'dot_number': dotNumber,
      'scac': scac,
      'status': status.dbValue,
      'address_id': addressId,
      'primary_contact_id': primaryContactId,
      'insurance_expiration': insuranceExpiration?.toIso8601String(),
      'safety_rating': safetyRating?.dbValue,
      'notes': notes,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'],
      companyId: json['company_id'],
      name: json['name'],
      mcNumber: json['mc_number'],
      dotNumber: json['dot_number'],
      scac: json['scac'],
      status: PartnerStatus.fromDbValue(json['status'] ?? 'onboarding'),
      addressId: json['address_id'],
      primaryContactId: json['primary_contact_id'],
      insuranceExpiration: json['insurance_expiration'] != null
          ? DateTime.parse(json['insurance_expiration'])
          : null,
      safetyRating: json['safety_rating'] != null
          ? SafetyRating.fromDbValue(json['safety_rating'])
          : null,
      notes: json['notes'],
      currency: json['currency'] ?? 'USD',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
