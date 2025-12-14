/// Enum representing user roles
enum UserRole {
  admin,
  dispatcher,
  driver,
  safetyOfficer,
  assistant;

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
    }
  }
}

/// Model representing a user profile
class UserProfile {
  final String id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.role = UserRole.driver,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? email ?? 'Unknown';
  }

  /// Create UserProfile from JSON (Supabase response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: _parseRole(json['role'] as String?),
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
      'first_name': firstName,
      'last_name': lastName,
      'role': role.name, // Store as string in DB
    };
  }

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.driver;
    try {
      return UserRole.values.firstWhere((e) => e.name == roleStr);
    } catch (_) {
      return UserRole.driver; // Fallback
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
