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
  ValueListenable<Box<String>>? _hiveListenable;

  ProfileProvider() {
    // Listen to auth state changes to manage cache
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _handleAuthChange();
    });
    // Initialize current state
    _handleAuthChange();
  }

  Future<void> _handleAuthChange() async {
    final uid = ProfileService.currentUserId;

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
    _hiveListenable?.removeListener(_onHiveChange);
    super.dispose();
  }
}
