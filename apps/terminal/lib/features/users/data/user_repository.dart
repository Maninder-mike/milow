import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  /// Fetch all user profiles using the rpc or direct table access if configured
  /// Note: standard Supabase auth.users isn't directly queryable by default.
  /// We assume a 'profiles' table exists that mirrors auth users + roles.
  Future<List<UserProfile>> fetchUsers({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    var query = _supabase.from('profiles').select();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('full_name', ascending: true)
        .range(start, end);

    // ignore: unnecessary_lambdas
    return (response as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
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
