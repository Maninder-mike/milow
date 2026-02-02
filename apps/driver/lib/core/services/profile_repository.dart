import 'dart:async';

import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/profile_service.dart';

class ProfileRepository {
  /// Returns cached profile immediately (may be null), and optionally refreshes
  /// from Supabase in the background. Returns the cached value.
  static Future<Map<String, dynamic>?> getCachedFirst({
    bool refresh = true,
  }) async {
    final uid = ProfileService.currentUserId;
    if (uid == null) return null;

    final cached = LocalProfileStore.get(uid);

    if (refresh) {
      // Fire-and-forget refresh
      unawaited(_refreshAndCache(uid));
    }

    return cached;
  }

  /// Explicitly fetches from Supabase and caches the result. Returns the latest value.
  static Future<Map<String, dynamic>?> refresh() async {
    final uid = ProfileService.currentUserId;
    if (uid == null) return null;
    return _refreshAndCache(uid);
  }

  static Future<Map<String, dynamic>?> _refreshAndCache(String uid) async {
    final remote = await ProfileService.getProfile(coalesceKey: 'profile:$uid');
    if (remote != null) {
      await LocalProfileStore.put(uid, remote);
    }
    return remote;
  }

  /// Optimistic update: write to cache first, then upsert to Supabase.
  /// If remote fails, it will rethrow; caller can decide to show error and/or retry.
  static Future<void> updateOptimistic(Map<String, dynamic> values) async {
    final uid = ProfileService.currentUserId;
    if (uid == null) return;

    final current = LocalProfileStore.get(uid) ?? <String, dynamic>{'id': uid};
    final optimistic = {...current, ...values};

    // Immediate cache update for instant UI response
    await LocalProfileStore.put(uid, optimistic);

    // Persist to Supabase; on success it remains consistent.
    await ProfileService.updateProfile(values);

    // Optionally refresh from server to pick any canonical fields (e.g., updated_at)
    await _refreshAndCache(uid);
  }
}
