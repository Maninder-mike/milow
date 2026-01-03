import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(Supabase.instance.client);
});

/// Provider that listens to real-time changes on the profiles table.
/// When a profile is updated (e.g., driver accepts verification), it
/// automatically refreshes the usersProvider so the drivers list updates instantly.
final profilesRealtimeProvider = StreamProvider<void>((ref) {
  final supabase = Supabase.instance.client;

  // Stream changes from profiles table
  return supabase.from('profiles').stream(primaryKey: ['id']).map((data) {
    // When any profile changes, refresh the users list
    ref.invalidate(usersProvider);
    return;
  });
});

final usersProvider = AsyncNotifierProvider<UsersController, List<UserProfile>>(
  UsersController.new,
);

class UsersController extends AsyncNotifier<List<UserProfile>> {
  int _page = 0;
  final int _pageSize = 20;
  String? _searchQuery;

  @override
  Future<List<UserProfile>> build() async {
    // Watch the realtime provider to keep it active
    ref.watch(profilesRealtimeProvider);
    return _fetch();
  }

  Future<List<UserProfile>> _fetch() async {
    final repository = ref.read(userRepositoryProvider);
    return repository.fetchUsers(
      page: _page,
      pageSize: _pageSize,
      searchQuery: _searchQuery,
    );
  }

  Future<void> setPage(int page) async {
    _page = page;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> setSearch(String query) async {
    _searchQuery = query;
    _page = 0; // Reset to first page on search
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  int get page => _page;
  int get pageSize => _pageSize;
  bool get hasFilter => _searchQuery != null && _searchQuery!.isNotEmpty;

  // Helper to get total count if needed?
  // For now, infinite scroll / next page logic usually just checks if items < pageSize.
}
