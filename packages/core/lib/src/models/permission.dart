/// Represents a permission action in the system.
///
/// Permissions are defined per resource with read/write/delete capabilities.
class Permission {
  final String id;

  /// The permission code, e.g., 'vehicles.read', 'trips.delete'
  final String code;

  /// The category this permission belongs to, e.g., 'vehicles', 'trips', 'admin'
  final String category;

  /// Human-readable description of what this permission grants
  final String? description;

  /// Whether this permission grants read access
  final bool canRead;

  /// Whether this permission grants write (create/update) access
  final bool canWrite;

  /// Whether this permission grants delete access
  final bool canDelete;

  final DateTime? createdAt;

  const Permission({
    required this.id,
    required this.code,
    required this.category,
    this.description,
    this.canRead = false,
    this.canWrite = false,
    this.canDelete = false,
    this.createdAt,
  });

  /// Create Permission from Supabase JSON response
  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      code: json['code'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      canRead: json['can_read'] as bool? ?? false,
      canWrite: json['can_write'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'category': category,
      'description': description,
      'can_read': canRead,
      'can_write': canWrite,
      'can_delete': canDelete,
    };
  }

  /// Get the resource name from the permission code
  /// e.g., 'vehicles.read' -> 'vehicles'
  String get resource => code.split('.').first;

  /// Get the action from the permission code
  /// e.g., 'vehicles.read' -> 'read'
  String get action => code.split('.').length > 1 ? code.split('.').last : '';

  Permission copyWith({
    String? id,
    String? code,
    String? category,
    String? description,
    bool? canRead,
    bool? canWrite,
    bool? canDelete,
    DateTime? createdAt,
  }) {
    return Permission(
      id: id ?? this.id,
      code: code ?? this.code,
      category: category ?? this.category,
      description: description ?? this.description,
      canRead: canRead ?? this.canRead,
      canWrite: canWrite ?? this.canWrite,
      canDelete: canDelete ?? this.canDelete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;

  @override
  String toString() =>
      'Permission($code: read=$canRead, write=$canWrite, delete=$canDelete)';
}
