import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:milow_core/src/services/app_logger.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Keys
  static const String keyMinSupportedVersion = 'min_supported_version';
  static const String keyFeatureAddEntryV2 =
      'feature_add_entry_v2'; // Example feature flag

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : const Duration(minutes: 5), // Frequent refresh in debug
        ),
      );

      // Set defaults
      await _remoteConfig.setDefaults(<String, dynamic>{
        keyMinSupportedVersion: '1.0.0', // Lowest possible version
        keyFeatureAddEntryV2: false,
      });

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();

      AppLogger.info('Remote Config initialized');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize Remote Config',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // Getters
  String get minSupportedVersion =>
      _remoteConfig.getString(keyMinSupportedVersion);

  bool get featureAddEntryV2 => _remoteConfig.getBool(keyFeatureAddEntryV2);

  // Generic Getters
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
}
