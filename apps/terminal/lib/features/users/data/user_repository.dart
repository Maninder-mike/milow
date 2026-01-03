import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  /// Fetch all user profiles for the current user's company.
  /// Filters by company_id to ensure multi-tenant isolation.
  Future<List<UserProfile>> fetchUsers({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    // Get current user's company_id to filter by company
    final currentUserId = _supabase.auth.currentUser?.id;
    String? companyId;

    if (currentUserId != null) {
      final currentProfile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', currentUserId)
          .maybeSingle();
      companyId = currentProfile?['company_id'] as String?;
    }

    // Select base profile + joined details from both tables
    var query = _supabase
        .from('profiles')
        .select('*, driver_profiles(*), company_staff_profiles(*)');

    // Filter by company_id if available
    // Include users with matching company OR users without company_id (legacy/pending)
    if (companyId != null) {
      query = query.or('company_id.eq.$companyId,company_id.is.null');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('full_name', ascending: true)
        .range(start, end);

    // Flatten the response before parsing
    return (response as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      // If it has driver details, merge them
      if (map['driver_profiles'] != null) {
        map.addAll(map['driver_profiles'] as Map<String, dynamic>);
        map.remove('driver_profiles');
      }
      // If it has staff details, merge them (priority to driver if somehow both exist, or vice versa, doesn't matter much as IDs are unique per role usually)
      if (map['company_staff_profiles'] != null) {
        map.addAll(map['company_staff_profiles'] as Map<String, dynamic>);
        map.remove('company_staff_profiles');
      }
      return UserProfile.fromJson(map);
    }).toList();
  }

  /// Update a user's role and verification status
  Future<void> updateUserStatus({
    required String userId,
    UserRole? role,
    bool? isVerified,
  }) async {
    final updates = <String, dynamic>{};
    if (role != null) updates['role'] = role.name;
    if (isVerified != null) updates['is_verified'] = isVerified;

    if (updates.isEmpty) return;

    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  /// Create a new user (Admin specific)
  /// Uses a temporary Supabase client to avoid logging out the admin.
  Future<void> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    // Create a temporary client to sign up the new user
    // This allows the admin to stay logged in while creating a new user
    final tempClient = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseAnonKey,
    );

    try {
      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': '$firstName $lastName'.trim(), 'role': role.name},
      );

      if (response.user == null) {
        throw 'Failed to create user: No user returned (maybe email exists?)';
      }

      final userId = response.user!.id;

      // Dispose temp client if necessary or just let it GC
      await tempClient.dispose();

      // Now, as Admin (current session), update the new user's profile to the correct role/verification
      // The trigger created them as 'pending' and unverified.
      await updateUserStatus(
        userId: userId,
        role: role,
        isVerified: true, // Auto-verify since Admin created them
      );
    } catch (e) {
      await tempClient.dispose();
      rethrow;
    }
  }
}
