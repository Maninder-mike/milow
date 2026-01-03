import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_provider.dart';

// Simple model or use Map for now since we just need 'role' and 'is_verified'
typedef ProfileData = Map<String, dynamic>;

final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileData?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<ProfileData?> {
  SupabaseClient get _client => ref.read(supabaseClientProvider);

  @override
  Future<ProfileData?> build() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<ProfileData?> _fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('*, company_staff_profiles(*), driver_profiles(*)')
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle to avoid 406/JSON error if not found

      if (data == null) return null;

      // Flatten details
      if (data['company_staff_profiles'] != null) {
        data.addAll(data['company_staff_profiles'] as Map<String, dynamic>);
        data.remove('company_staff_profiles');
      }
      if (data['driver_profiles'] != null) {
        data.addAll(data['driver_profiles'] as Map<String, dynamic>);
        data.remove('driver_profiles');
      }

      return data;
    } catch (e) {
      // Return null on error so we can retry or handle gracefully
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      return _fetchProfile(user.id);
    });
  }
}
