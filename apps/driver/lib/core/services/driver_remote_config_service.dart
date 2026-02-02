import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Service for managing feature flags and remote configuration.
///
/// Use this for gradual rollouts, A/B testing, and emergency kill switches.
class DriverRemoteConfigService {
  static final DriverRemoteConfigService instance =
      DriverRemoteConfigService._internal();
  factory DriverRemoteConfigService() => instance;
  DriverRemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  /// Default values for all config keys
  static const Map<String, dynamic> _defaults = {
    // Feature flags
    'geofence_enabled': true,
    'receipt_scanner_enabled': true,
    'expense_tracking_enabled': true,
    'document_sync_enabled': true,

    // Configuration
    'geofence_radius_meters': 500,
    'sync_interval_minutes': 15,
    'max_offline_days': 7,

    // Rollout percentages (0-100)
    'new_trip_ui_rollout': 0,

    // Emergency
    'force_update_version': '0.0.0',
    'maintenance_mode': false,
  };

  /// Initialize remote config
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 5)
              : const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults(_defaults);
      await _remoteConfig.fetchAndActivate();
      _initialized = true;
      debugPrint('[RemoteConfig] Initialized');
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to initialize: $e');
    }
  }

  /// Refresh config from server
  Future<bool> refresh() async {
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] Refreshed, activated: $activated');
      return activated;
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to refresh: $e');
      return false;
    }
  }

  // ==================== FEATURE FLAGS ====================

  bool get geofenceEnabled => _remoteConfig.getBool('geofence_enabled');
  bool get receiptScannerEnabled =>
      _remoteConfig.getBool('receipt_scanner_enabled');
  bool get expenseTrackingEnabled =>
      _remoteConfig.getBool('expense_tracking_enabled');
  bool get documentSyncEnabled =>
      _remoteConfig.getBool('document_sync_enabled');

  // ==================== CONFIGURATION ====================

  int get geofenceRadiusMeters =>
      _remoteConfig.getInt('geofence_radius_meters');
  int get syncIntervalMinutes => _remoteConfig.getInt('sync_interval_minutes');
  int get maxOfflineDays => _remoteConfig.getInt('max_offline_days');

  // ==================== ROLLOUT ====================

  int get newTripUiRollout => _remoteConfig.getInt('new_trip_ui_rollout');

  /// Check if feature is enabled for this user based on rollout percentage
  bool isFeatureRolledOut(String featureKey, String userId) {
    final percentage = _remoteConfig.getInt(featureKey);
    if (percentage >= 100) return true;
    if (percentage <= 0) return false;

    // Simple hash-based rollout
    final hash = userId.hashCode.abs() % 100;
    return hash < percentage;
  }

  // ==================== EMERGENCY ====================

  String get forceUpdateVersion =>
      _remoteConfig.getString('force_update_version');
  bool get maintenanceMode => _remoteConfig.getBool('maintenance_mode');

  // ==================== GENERIC ====================

  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
}

/// Global instance
final driverRemoteConfigService = DriverRemoteConfigService.instance;
