import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/logging_service.dart';

class AuthService {
  static const String _biometricEnabledKey = 'biometric_enabled';

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> hasValidSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null;
  }

  static Future<void> signOut() async {
    final uid = ProfileService.currentUserId;
    if (uid != null) {
      // Clear FCM token in Supabase
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', uid);
      } catch (e) {
        // Log error but continue with sign out
        unawaited(logger.error('Auth', 'Failed to clear FCM token', error: e));
      }

      // Clear local cached profile
      await LocalProfileStore.delete(uid);
    }
    await Supabase.instance.client.auth.signOut();
  }

  static String? getCurrentUserEmail() {
    return Supabase.instance.client.auth.currentUser?.email;
  }

  static String? getCurrentUserName() {
    return Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['full_name'];
  }
}
