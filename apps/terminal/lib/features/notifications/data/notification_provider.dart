import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider that streams a list of pending (unverified) users.
final pendingUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final supabase = Supabase.instance.client;
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

/// Provider for notification actions
final notificationActionsProvider = Provider((ref) => NotificationActions());

class NotificationActions {
  NotificationActions();
  Future<void> approveUser(String userId, UserRole role) async {
    final client = Supabase.instance.client;
    final adminId = client.auth.currentUser?.id;

    String? companyName;
    if (adminId != null) {
      // Fetch admin's company name
      final adminData = await client
          .from('profiles')
          .select('company_name')
          .eq('id', adminId)
          .maybeSingle();
      companyName = adminData?['company_name'] as String?;
    }

    await client
        .from('profiles')
        .update({
          'role': role.name,
          'is_verified': true,
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
    await Supabase.instance.client.from('profiles').delete().eq('id', userId);

    // Note: This only deletes the profile. The Auth user remains but has no profile data.
    // In a real app we'd want a specialized Edge Function to delete the Auth User too.
    // For this MVP, deleting the profile clears the notification.
  }
}
