import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

part 'user_preferences_provider.g.dart';

class UserPreferencesState {
  final bool opsPush;
  final bool opsEmail;
  final bool msgPush;
  final bool msgEmail;
  final bool safetyPush;
  final bool safetyEmail;
  final bool accountPush;
  final bool accountEmail;
  final double syncFrequency;
  final String language;
  final String mapProvider;
  final String unitSystem; // 'Imperial' or 'Metric'

  const UserPreferencesState({
    required this.opsPush,
    required this.opsEmail,
    required this.msgPush,
    required this.msgEmail,
    required this.safetyPush,
    required this.safetyEmail,
    required this.accountPush,
    required this.accountEmail,
    required this.syncFrequency,
    required this.language,
    required this.mapProvider,
    required this.unitSystem,
  });

  UserPreferencesState copyWith({
    bool? opsPush,
    bool? opsEmail,
    bool? msgPush,
    bool? msgEmail,
    bool? safetyPush,
    bool? safetyEmail,
    bool? accountPush,
    bool? accountEmail,
    double? syncFrequency,
    String? language,
    String? mapProvider,
    String? unitSystem,
  }) {
    return UserPreferencesState(
      opsPush: opsPush ?? this.opsPush,
      opsEmail: opsEmail ?? this.opsEmail,
      msgPush: msgPush ?? this.msgPush,
      msgEmail: msgEmail ?? this.msgEmail,
      safetyPush: safetyPush ?? this.safetyPush,
      safetyEmail: safetyEmail ?? this.safetyEmail,
      accountPush: accountPush ?? this.accountPush,
      accountEmail: accountEmail ?? this.accountEmail,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      language: language ?? this.language,
      mapProvider: mapProvider ?? this.mapProvider,
      unitSystem: unitSystem ?? this.unitSystem,
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
      opsPush: _prefs.getBool('notifications_ops_push') ?? true,
      opsEmail: _prefs.getBool('notifications_ops_email') ?? true,
      msgPush: _prefs.getBool('notifications_msg_push') ?? true,
      msgEmail: _prefs.getBool('notifications_msg_email') ?? true,
      safetyPush: _prefs.getBool('notifications_safety_push') ?? true,
      safetyEmail: _prefs.getBool('notifications_safety_email') ?? true,
      accountPush: _prefs.getBool('notifications_account_push') ?? true,
      accountEmail: _prefs.getBool('notifications_account_email') ?? true,
      syncFrequency: _prefs.getDouble('sync_frequency') ?? 50.0,
      language: _prefs.getString('language') ?? 'English',
      mapProvider: _prefs.getString('map_provider') ?? 'Default Map',
      unitSystem: _prefs.getString('unit_system') ?? 'Imperial',
    );
  }

  Future<void> setOpsPush(bool value) async {
    await _prefs.setBool('notifications_ops_push', value);
    state = state.copyWith(opsPush: value);
  }

  Future<void> setOpsEmail(bool value) async {
    await _prefs.setBool('notifications_ops_email', value);
    state = state.copyWith(opsEmail: value);
  }

  Future<void> setMsgPush(bool value) async {
    await _prefs.setBool('notifications_msg_push', value);
    state = state.copyWith(msgPush: value);
  }

  Future<void> setMsgEmail(bool value) async {
    await _prefs.setBool('notifications_msg_email', value);
    state = state.copyWith(msgEmail: value);
  }

  Future<void> setSafetyPush(bool value) async {
    await _prefs.setBool('notifications_safety_push', value);
    state = state.copyWith(safetyPush: value);
  }

  Future<void> setSafetyEmail(bool value) async {
    await _prefs.setBool('notifications_safety_email', value);
    state = state.copyWith(safetyEmail: value);
  }

  Future<void> setAccountPush(bool value) async {
    await _prefs.setBool('notifications_account_push', value);
    state = state.copyWith(accountPush: value);
  }

  Future<void> setAccountEmail(bool value) async {
    await _prefs.setBool('notifications_account_email', value);
    state = state.copyWith(accountEmail: value);
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

  Future<void> setUnitSystem(String value) async {
    await _prefs.setString('unit_system', value);
    state = state.copyWith(unitSystem: value);
  }
}
