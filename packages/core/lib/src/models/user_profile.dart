enum UserRole {
  admin,
  dispatcher,
  driver,
  safetyOfficer,
  assistant,
  accountant,
  pending;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.dispatcher:
        return 'Dispatcher';
      case UserRole.driver:
        return 'Driver';
      case UserRole.safetyOfficer:
        return 'Safety Officer';
      case UserRole.assistant:
        return 'Assistant';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.pending:
        return 'Pending';
    }
  }
}

/// Model representing a user profile
/// Model representing a user profile
class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? roleId; // New: FK to roles table
  final UserRole role; // Legacy: Keep for backwards compat
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? licenseNumber;
  final DateTime? licenseExpiryDate;
  final String? licenseType;
  final String? citizenship;
  final String? fastId;

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.roleId,
    required this.role,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.licenseNumber,
    this.licenseExpiryDate,
    this.licenseType,
    this.citizenship,
    this.fastId,
  });

  /// Create UserProfile from JSON (Supabase response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleId: json['role_id'] as String?,
      role: _parseRole(json['role'] as String?),
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      licenseNumber: json['license_number'] as String?,
      licenseExpiryDate: json['license_expiry_date'] != null
          ? DateTime.tryParse(json['license_expiry_date'] as String)
          : null,
      licenseType: json['license_type'] as String?,
      citizenship: json['citizenship'] as String?,
      fastId: json['fast_id'] as String?,
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role_id': roleId,
      'role': role.name, // Store as string in DB
      'is_verified': isVerified,
      'license_number': licenseNumber,
      'license_expiry_date': licenseExpiryDate?.toIso8601String(),
      'license_type': licenseType,
      'citizenship': citizenship,
      'fast_id': fastId,
    };
  }

  static UserRole _parseRole(String? role) {
    if (role == null) return UserRole.pending;
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == role.toLowerCase(),
      orElse: () => UserRole.pending,
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? roleId,
    UserRole? role,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? licenseNumber,
    DateTime? licenseExpiryDate,
    String? licenseType,
    String? citizenship,
    String? fastId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roleId: roleId ?? this.roleId,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
      licenseType: licenseType ?? this.licenseType,
      citizenship: citizenship ?? this.citizenship,
      fastId: fastId ?? this.fastId,
    );
  }
}
