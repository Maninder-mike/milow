import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/local_profile_store.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;

  late final StreamSubscription<AuthState> _authSub;
  RealtimeChannel? _channel;
  ValueListenable<Box<String>>? _hiveListenable;

  ProfileProvider() {
    // Listen to auth state changes to manage subscriptions and cache
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _handleAuthChange();
    });
    // Initialize current state
    _handleAuthChange();
  }

  Future<void> _handleAuthChange() async {
    final uid = ProfileService.currentUserId;

    // Cancel realtime channel if user changed or signed out
    await _channel?.unsubscribe();
    _channel = null;

    // Remove Hive listener
    _hiveListenable?.removeListener(_onHiveChange);
    _hiveListenable = null;

    if (uid == null) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    // Load cached immediately
    _loading = true;
    _profile = LocalProfileStore.get(uid);
    _loading = false;
    notifyListeners();

    // Listen to Hive box to reflect local updates instantly
    _hiveListenable = LocalProfileStore.watchBox();
    _hiveListenable!.addListener(_onHiveChange);

    // Subscribe to realtime updates for this user's profile (UPDATE/INSERT)
    _channel = Supabase.instance.client.channel('public:profiles')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'profiles',
        callback: (payload) {
          final row = payload.newRecord;
          if (row['id'] == uid) {
            ProfileRepository.refresh();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        callback: (payload) {
          final row = payload.newRecord;
          if (row['id'] == uid) {
            ProfileRepository.refresh();
          }
        },
      )
      ..subscribe();

    // Background refresh to ensure latest
    unawaited(ProfileRepository.refresh());
  }

  void _onHiveChange() {
    final uid = ProfileService.currentUserId;
    if (uid == null) return;
    final next = LocalProfileStore.get(uid);
    if (!mapEquals(next, _profile)) {
      _profile = next;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    await ProfileRepository.refresh();
    _loading = false;
    notifyListeners();
  }

  Future<void> update(Map<String, dynamic> values) async {
    await ProfileRepository.updateOptimistic(values);
  }

  @override
  void dispose() {
    _authSub.cancel();
    _channel?.unsubscribe();
    _hiveListenable?.removeListener(_onHiveChange);
    super.dispose();
  }
}
