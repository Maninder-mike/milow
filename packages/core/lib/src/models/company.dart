class Company {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoUrl;
  final String? plan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? dotNumber;
  final String? mcNumber;

  // Enterprise Settings
  final String? hosRuleSet;
  final double? maxGovernanceSpeed;
  final bool enforce2fa;
  final int passwordRotationDays;
  final String? dispatchWebhookUrl;
  final List<dynamic>? apiKeys;

  const Company({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    this.plan,
    this.createdAt,
    this.updatedAt,
    this.hosRuleSet,
    this.maxGovernanceSpeed,
    this.enforce2fa = false,
    this.passwordRotationDays = 90,
    this.dispatchWebhookUrl,
    this.apiKeys,
    this.dotNumber,
    this.mcNumber,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] as String?,
      plan: json['plan'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      hosRuleSet: json['hos_rule_set'] as String?,
      maxGovernanceSpeed: json['max_governance_speed'] != null
          ? (json['max_governance_speed'] as num).toDouble()
          : null,
      enforce2fa: json['enforce_2fa'] as bool? ?? false,
      passwordRotationDays: json['password_rotation_days'] as int? ?? 90,
      dispatchWebhookUrl: json['dispatch_webhook_url'] as String?,
      apiKeys: json['api_keys'] as List<dynamic>?,
      dotNumber: json['dot_number'] as String?,
      mcNumber: json['mc_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'logo_url': logoUrl,
      'plan': plan,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'hos_rule_set': hosRuleSet,
      'max_governance_speed': maxGovernanceSpeed,
      'enforce_2fa': enforce2fa,
      'password_rotation_days': passwordRotationDays,
      'dispatch_webhook_url': dispatchWebhookUrl,
      'api_keys': apiKeys,
      'dot_number': dotNumber,
      'mc_number': mcNumber,
    };
  }
}
