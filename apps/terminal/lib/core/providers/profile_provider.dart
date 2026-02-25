import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:terminal/core/providers/supabase_provider.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<Map<String, dynamic>?> build() async {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return null;

    final response = await ref
        .watch(supabaseClientProvider)
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final id = profile['id'];
    if (id == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .update(profile)
          .eq('id', id);
      return profile;
    });
  }
}
