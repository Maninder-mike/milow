import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

/// Provider that streams a list of pending (unverified) users.
final pendingUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final currentUserEmail = supabase.auth.currentUser?.email;

  if (currentUserEmail == null) return Stream.value([]);

  // Stream changes from 'profiles' table where is_verified is false
  // We can't easily filter by target_admin_email in the stream query itself
  // without creating a more complex publication or using a specific filter that matches exactly.
  // Instead, we fetch pending users and filter in-memory which is fine for this scale.
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('is_verified', false)
      .order('updated_at', ascending: false)
      .map((data) {
        final users = <UserProfile>[];
        for (final json in data) {
          try {
            users.add(UserProfile.fromJson(json));
          } catch (e) {
            // Skip invalid user data and log if possible
            // debugPrint('Error parsing user: $e');
            continue;
          }
        }

        // Filter users to only those in the same organization (matching email domain)
        // e.g. admin@company.com sees requests from user@company.com
        if (currentUserEmail.contains('@')) {
          final adminDomain = currentUserEmail.split('@').last;
          return users.where((u) {
            final userEmail = u.email;
            if (userEmail == null || !userEmail.contains('@')) return false;
            return userEmail.split('@').last == adminDomain;
          }).toList();
        }

        return users;
      });
});

/// Provider that streams driver_left notifications for the current admin.
/// These notifications are created when a driver leaves a company.
final driverLeftNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final supabase = ref.watch(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return Stream.value([]);

      return supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((data) {
            // Filter to only driver_left type notifications that are unread
            return data
                .where(
                  (n) => n['type'] == 'driver_left' && n['is_read'] != true,
                )
                .toList()
                .cast<Map<String, dynamic>>();
          });
    });

/// Provider that streams company_invite notifications for the current admin.
/// These include "Verification Accepted" and "Verification Declined" from drivers.
final companyInviteNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final supabase = ref.watch(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return Stream.value([]);

      return supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((data) {
            // Filter to only company_invite type notifications that are unread
            return data
                .where(
                  (n) => n['type'] == 'company_invite' && n['is_read'] != true,
                )
                .toList()
                .cast<Map<String, dynamic>>();
          });
    });

/// Provider for notification actions
final notificationActionsProvider = Provider(
  (ref) => NotificationActions(ref.watch(supabaseClientProvider)),
);

class NotificationActions {
  final SupabaseClient _client;
  NotificationActions(this._client);
  Future<void> approveUser(String userId, UserRole role) async {
    final client = _client;
    final adminId = client.auth.currentUser?.id;

    String? companyId;
    String? companyName;
    if (adminId != null) {
      // Fetch admin's company_id and company_name to assign to the verified user
      final adminData = await client
          .from('profiles')
          .select('company_id, company_name')
          .eq('id', adminId)
          .maybeSingle();
      companyId = adminData?['company_id'] as String?;
      companyName = adminData?['company_name'] as String?;
    }

    // Update user profile
    // NOTE: The database trigger `notify_on_verification` automatically
    // sends a notification to the driver when is_verified changes to true.
    await client
        .from('profiles')
        .update({
          'role': role.name,
          'is_verified': true,
          if (companyId != null) 'company_id': companyId,
          if (companyName != null) 'company_name': companyName,
        })
        .eq('id', userId);
  }

  Future<void> rejectUser(String userId) async {
    // For now, "Reject" might mean delete or just ignore.
    // The user requirement implies explicit rejection.
    // We could add a 'rejected' status or delete.
    // Safest is to perhaps just delete the profile/user if they are genuinely spam/invalid.
    // But for safety, let's assuming deleting the AUTH user is hard from client (requires service role usually).
    // So let's just delete the profile row?
    // Actually, update status to 'pending' (no change) just dismisses notifications?
    // User requested "Reject".
    // Let's implement DELETE for now as it removes them from the pending queue.
    await _client.from('profiles').delete().eq('id', userId);

    // Note: This only deletes the profile. The Auth user remains but has no profile data.
    // In a real app we'd want a specialized Edge Function to delete the Auth User too.
    // For this MVP, deleting the profile clears the notification.
  }

  /// Mark a notification as read/dismissed
  Future<void> dismissNotification(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all unread notifications as read for the current user
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
