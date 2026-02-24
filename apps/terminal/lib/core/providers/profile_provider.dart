import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/core/providers/supabase_provider.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return null;

    final response = await ref
        .watch(supabaseClientProvider)
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
      return profile;
    });
  }
}
