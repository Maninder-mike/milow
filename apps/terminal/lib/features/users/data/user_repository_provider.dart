import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'user_repository.dart';

part 'user_repository_provider.g.dart';

@riverpod
UserRepository userRepository(Ref ref) {
  return UserRepository(Supabase.instance.client);
}

@riverpod
Future<List<UserProfile>> users(Ref ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.fetchUsers();
}
