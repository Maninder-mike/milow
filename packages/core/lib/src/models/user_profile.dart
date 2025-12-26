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
  final UserRole role; // Uses the updated UserRole enum
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Create UserProfile from JSON (Supabase response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: _parseRole(json['role'] as String?),
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
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
      'role': role.name, // Store as string in DB
      'is_verified': isVerified,
    };
  }

  static UserRole _parseRole(String? role) {
    if (role == null) return UserRole.pending;
    return UserRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => UserRole.pending,
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
