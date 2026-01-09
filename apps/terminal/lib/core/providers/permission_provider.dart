import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'permission_provider.g.dart';

/// Provider for user permissions based on their role.
///
/// This fetches permissions from the database based on the user's role_id.
/// For backwards compatibility, users with legacy role='admin' get full access.
/// Permissions are cached locally for 5 minutes to reduce database calls.

const _cacheKey = 'user_permissions_cache';
const _cacheTimestampKey = 'user_permissions_timestamp';
const _cacheDuration = Duration(minutes: 5);

/// Represents a user's permission set with helper methods
class UserPermissions {
  final Set<String> _permissions;
  final bool isAdmin;

  const UserPermissions._(this._permissions, {this.isAdmin = false});

  /// Empty permissions (not logged in or no permissions)
  factory UserPermissions.empty() => const UserPermissions._({});

  /// Full admin permissions
  factory UserPermissions.admin() => const UserPermissions._({}, isAdmin: true);

  /// Create from cached JSON
  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions._(
      Set<String>.from(json['permissions'] as List? ?? []),
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    'permissions': _permissions.toList(),
    'isAdmin': isAdmin,
  };

  /// Check if user has a specific permission
  bool has(String permissionCode) =>
      isAdmin || _permissions.contains(permissionCode);

  /// Check read permission for a resource
  bool canRead(String resource) =>
      isAdmin || _permissions.contains('$resource.read');

  /// Check write permission for a resource
  bool canWrite(String resource) =>
      isAdmin || _permissions.contains('$resource.write');

  /// Check delete permission for a resource
  bool canDelete(String resource) =>
      isAdmin || _permissions.contains('$resource.delete');

  /// Check if user can manage a resource (read + write)
  bool canManage(String resource) => canRead(resource) && canWrite(resource);

  /// Get all permission codes
  Set<String> get all => isAdmin ? {'*'} : _permissions;

  @override
  String toString() =>
      isAdmin ? 'UserPermissions(admin)' : 'UserPermissions($_permissions)';
}

/// Fetches and caches user permissions from Supabase
@riverpod
Future<UserPermissions> userPermissions(Ref ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return UserPermissions.empty();
  }

  // Try to load from cache first
  final prefs = await SharedPreferences.getInstance();
  final cachedTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;
  final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;

  if (cacheAge < _cacheDuration.inMilliseconds) {
    final cachedData = prefs.getString(_cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData) as Map<String, dynamic>;
        if (json['userId'] == userId) {
          return UserPermissions.fromJson(json);
        }
      } catch (_) {
        // Cache corrupted, continue to fetch
      }
    }
  }

  // Fetch from database
  final profileResponse = await supabase
      .from('profiles')
      .select('role, role_id')
      .eq('id', userId)
      .maybeSingle();

  if (profileResponse == null) {
    return UserPermissions.empty();
  }

  final legacyRole = profileResponse['role'] as String?;
  final roleId = profileResponse['role_id'] as String?;

  // Admin always has full access
  if (legacyRole == 'admin') {
    final adminPerms = UserPermissions.admin();
    await _cachePermissions(prefs, userId, adminPerms);
    return adminPerms;
  }

  // If no role_id assigned, use empty permissions
  if (roleId == null) {
    return UserPermissions.empty();
  }

  // Fetch permissions for the user's role
  final permissionsResponse = await supabase
      .from('role_permissions')
      .select('''
        can_read,
        can_write,
        can_delete,
        permissions!inner(code)
      ''')
      .eq('role_id', roleId);

  final permissions = <String>{};

  for (final rp in permissionsResponse as List<dynamic>) {
    final code = rp['permissions']?['code'] as String?;
    if (code == null) continue;

    if (rp['can_read'] == true) {
      permissions.add(code);
    }
    if (rp['can_write'] == true) {
      permissions.add('${code.split('.').first}.write');
    }
    if (rp['can_delete'] == true) {
      permissions.add('${code.split('.').first}.delete');
    }
  }

  final userPerms = UserPermissions._(permissions);
  await _cachePermissions(prefs, userId, userPerms);
  return userPerms;
}

/// Cache permissions locally
Future<void> _cachePermissions(
  SharedPreferences prefs,
  String userId,
  UserPermissions permissions,
) async {
  final data = {'userId': userId, ...permissions.toJson()};
  await prefs.setString(_cacheKey, jsonEncode(data));
  await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
}

/// Clear permission cache (call after role changes)
Future<void> clearPermissionCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cacheKey);
  await prefs.remove(_cacheTimestampKey);
}

/// Provider for the current user's role details
@riverpod
Future<Map<String, dynamic>?> currentUserRole(Ref ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return null;

  final profileResponse = await supabase
      .from('profiles')
      .select('role_id')
      .eq('id', userId)
      .maybeSingle();

  final roleId = profileResponse?['role_id'] as String?;
  if (roleId == null) return null;

  final roleResponse = await supabase
      .from('roles')
      .select('''
        id,
        name,
        description,
        is_system_role,
        role_permissions(
          can_read,
          can_write,
          can_delete,
          permissions(id, code, category, description)
        )
      ''')
      .eq('id', roleId)
      .maybeSingle();

  return roleResponse;
}

/// Extension for easy permission checking in widgets
extension PermissionWidgetRef on WidgetRef {
  /// Get current permissions (null if loading or error)
  UserPermissions? get _permissions {
    final state = watch(userPermissionsProvider);
    return state.when(
      data: (p) => p,
      loading: () => null,
      error: (e, s) => null,
    );
  }

  /// Check if current user has a permission
  bool hasPermission(String permissionCode) {
    return _permissions?.has(permissionCode) ?? false;
  }

  /// Check if current user can read a resource
  bool canRead(String resource) {
    return _permissions?.canRead(resource) ?? false;
  }

  /// Check if current user can write to a resource
  bool canWrite(String resource) {
    return _permissions?.canWrite(resource) ?? false;
  }

  /// Check if current user can delete from a resource
  bool canDelete(String resource) {
    return _permissions?.canDelete(resource) ?? false;
  }
}
