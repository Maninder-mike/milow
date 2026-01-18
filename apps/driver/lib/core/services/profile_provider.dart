import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/notification_service.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;

  /// Whether the driver is connected to a company
  bool get isConnectedToCompany => _profile?['company_id'] != null;
  String? get companyName => _profile?['company_name'];

  late final StreamSubscription<AuthState> _authSub;
  StreamSubscription<String>? _fcmSub;
  ValueListenable<Box<String>>? _hiveListenable;

  ProfileProvider() {
    // Listen to auth state changes to manage cache
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _handleAuthChange();
    });
    // Initialize current state
    _handleAuthChange();

    // Listen to FCM token refresh
    _fcmSub = notificationService.onTokenRefresh.listen((token) {
      _updateFcmToken(token);
    });
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

    // Update FCM token on login
    unawaited(_updateFcmToken());
  }

  Future<void> _updateFcmToken([String? token]) async {
    final uid = ProfileService.currentUserId;
    if (uid == null) return;

    final fcmToken = token ?? await notificationService.getToken();
    if (fcmToken != null && fcmToken != _profile?['fcm_token']) {
      await update({'fcm_token': fcmToken});
    }
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
    _fcmSub?.cancel();
    _hiveListenable?.removeListener(_onHiveChange);
    super.dispose();
  }
}
