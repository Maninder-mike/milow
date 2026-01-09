import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

part 'user_preferences_provider.g.dart';

class UserPreferencesState {
  final bool emailAlerts;
  final bool pushNotifications;
  final double syncFrequency;
  final String language;
  final String mapProvider;

  const UserPreferencesState({
    required this.emailAlerts,
    required this.pushNotifications,
    required this.syncFrequency,
    required this.language,
    required this.mapProvider,
  });

  UserPreferencesState copyWith({
    bool? emailAlerts,
    bool? pushNotifications,
    double? syncFrequency,
    String? language,
    String? mapProvider,
  }) {
    return UserPreferencesState(
      emailAlerts: emailAlerts ?? this.emailAlerts,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      language: language ?? this.language,
      mapProvider: mapProvider ?? this.mapProvider,
    );
  }
}

@riverpod
class UserPreferencesNotifier extends _$UserPreferencesNotifier {
  late SharedPreferences _prefs;

  @override
  UserPreferencesState build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    return UserPreferencesState(
      emailAlerts: _prefs.getBool('email_alerts') ?? true,
      pushNotifications: _prefs.getBool('notifications_enabled') ?? true,
      syncFrequency: _prefs.getDouble('sync_frequency') ?? 50.0,
      language: _prefs.getString('language') ?? 'English',
      mapProvider: _prefs.getString('map_provider') ?? 'Default Map',
    );
  }

  Future<void> setEmailAlerts(bool value) async {
    await _prefs.setBool('email_alerts', value);
    state = state.copyWith(emailAlerts: value);
  }

  Future<void> setPushNotifications(bool value) async {
    await _prefs.setBool('notifications_enabled', value);
    state = state.copyWith(pushNotifications: value);
  }

  Future<void> setSyncFrequency(double value) async {
    await _prefs.setDouble('sync_frequency', value);
    state = state.copyWith(syncFrequency: value);
  }

  Future<void> setLanguage(String value) async {
    await _prefs.setString('language', value);
    state = state.copyWith(language: value);
  }

  Future<void> setMapProvider(String value) async {
    await _prefs.setString('map_provider', value);
    state = state.copyWith(mapProvider: value);
  }
}
