import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuditAction {
  create,
  update,
  delete,
  login,
  logout,
  view,
  export,
}

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  /// Logs a critical action to the audit trail.
  /// 
  /// [action]: The type of action performed.
  /// [resource]: The resource affected (e.g., 'Load', 'Driver', 'Settings').
  /// [details]: specific details about the change (e.g., 'Changed status to Delivered').
  /// [userId]: Optional user ID. Defaults to current authenticated user.
  Future<void> log(
    AuditAction action, {
    required String resource,
    required String details,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    final effectiveUserId = userId ?? Supabase.instance.client.auth.currentUser?.id;
    final timestamp = DateTime.now().toIso8601String();

    // 1. Console Logging (Dev Mode)
    if (kDebugMode) {
      debugPrint('📝 AUDIT [${action.name.toUpperCase()}] $resource: $details (User: $effectiveUserId)');
    }

    // 2. Database Logging
    try {
      await Supabase.instance.client.from('audit_logs').insert({
        'user_id': effectiveUserId,
        'action': action.name,
        'resource': resource,
        'details': details,
        'metadata': metadata,
        'created_at': timestamp,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to write audit log: $e');
      }
    }
  }
}
