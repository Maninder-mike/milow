import 'permission.dart';

/// Represents a role within a company that can be assigned to users.
///
/// Roles are company-specific and contain a set of permissions that
/// define what actions users with this role can perform.
class Role {
  final String id;

  /// The company this role belongs to (null for global/system roles)
  final String? companyId;

  /// Display name of the role, e.g., "Dispatcher", "Sales Manager"
  final String name;

  /// Description of what this role is for
  final String? description;

  /// System roles cannot be deleted or renamed
  final bool isSystemRole;

  /// Additional metadata stored as key-value pairs
  final Map<String, dynamic> metadata;

  /// The permissions granted to this role
  final List<Permission> permissions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Role({
    required this.id,
    this.companyId,
    required this.name,
    this.description,
    this.isSystemRole = false,
    this.metadata = const {},
    this.permissions = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Create Role from Supabase JSON response
  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      isSystemRole: json['is_system_role'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      permissions:
          (json['role_permissions'] as List<dynamic>?)
              ?.map((rp) {
                // role_permissions includes permission via join
                final permissionData =
                    rp['permissions'] as Map<String, dynamic>?;
                if (permissionData == null) return null;
                return Permission.fromJson({
                  ...permissionData,
                  'can_read': rp['can_read'] ?? false,
                  'can_write': rp['can_write'] ?? false,
                  'can_delete': rp['can_delete'] ?? false,
                });
              })
              .whereType<Permission>()
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'description': description,
      'is_system_role': isSystemRole,
      'metadata': metadata,
    };
  }

  /// Check if this role has a specific permission
  bool hasPermission(String permissionCode, {String action = 'read'}) {
    final permission = permissions.firstWhere(
      (p) => p.code == permissionCode,
      orElse: () => Permission(id: '', code: '', category: ''),
    );

    switch (action) {
      case 'read':
        return permission.canRead;
      case 'write':
        return permission.canWrite;
      case 'delete':
        return permission.canDelete;
      default:
        return false;
    }
  }

  /// Check if this role can read a resource
  bool canRead(String resource) =>
      hasPermission('$resource.read', action: 'read');

  /// Check if this role can write to a resource
  bool canWrite(String resource) =>
      hasPermission('$resource.write', action: 'write');

  /// Check if this role can delete from a resource
  bool canDelete(String resource) =>
      hasPermission('$resource.delete', action: 'delete');

  /// Get all permission codes this role has (for any action)
  Set<String> get permissionCodes => permissions.map((p) => p.code).toSet();

  /// Get count of users with this role (populated separately)
  int get memberCount => metadata['member_count'] as int? ?? 0;

  Role copyWith({
    String? id,
    String? companyId,
    String? name,
    String? description,
    bool? isSystemRole,
    Map<String, dynamic>? metadata,
    List<Permission>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystemRole: isSystemRole ?? this.isSystemRole,
      metadata: metadata ?? this.metadata,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role($name, permissions: ${permissions.length})';
}
