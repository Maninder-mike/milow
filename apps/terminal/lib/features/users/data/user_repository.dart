import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  /// Fetch all user profiles using the rpc or direct table access if configured
  /// Note: standard Supabase auth.users isn't directly queryable by default.
  /// We assume a 'profiles' table exists that mirrors auth users + roles.
  Future<List<UserProfile>> fetchUsers() async {
    final response = await _supabase
        .from('profiles')
        .select()
        .order('first_name', ascending: true);

    // ignore: unnecessary_lambdas
    return (response as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update a user's role
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _supabase
        .from('profiles')
        .update({'role': role.name})
        .eq('id', userId);
  }
}
