import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:milow/core/services/logging_service.dart';

/// Model for app version information from Supabase
class AppVersionInfo {
  final String platform;
  final String latestVersion;
  final String downloadUrl;
  final String? changelog;
  final String? minSupportedVersion;
  final bool isCritical;

  AppVersionInfo({
    required this.platform,
    required this.latestVersion,
    required this.downloadUrl,
    this.changelog,
    this.minSupportedVersion,
    this.isCritical = false,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      platform: json['platform'] as String,
      latestVersion: json['latest_version'] as String,
      downloadUrl: json['download_url'] as String,
      changelog: json['changelog'] as String?,
      minSupportedVersion: json['min_supported_version'] as String?,
      isCritical: json['is_critical'] as bool? ?? false,
    );
  }
}

/// Result of version check
class UpdateCheckResult {
  final bool updateAvailable;
  final bool isCriticalUpdate;
  final AppVersionInfo? versionInfo;
  final String? currentVersion;

  UpdateCheckResult({
    required this.updateAvailable,
    required this.isCriticalUpdate,
    this.versionInfo,
    this.currentVersion,
  });
}

/// Service to check for app updates from Supabase
class VersionCheckerService {
  static const String _lastCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 24);

  /// Check if an update is available
  /// Returns UpdateCheckResult with update information
  static Future<UpdateCheckResult> checkForUpdates({
    bool forceCheck = false,
  }) async {
    try {
      // Rate limiting: only check once per day unless forced
      if (!forceCheck && !await _shouldCheckForUpdate()) {
        await logger.info(
          'VersionCheck',
          'Skipping update check (rate limited)',
        );
        return UpdateCheckResult(
          updateAvailable: false,
          isCriticalUpdate: false,
        );
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      await logger.info('VersionCheck', 'Current version: $currentVersion');

      // Fetch latest version from Supabase
      final versionInfo = await _fetchLatestVersion();
      if (versionInfo == null) {
        await logger.warning('VersionCheck', 'Failed to fetch version info');
        return UpdateCheckResult(
          updateAvailable: false,
          isCriticalUpdate: false,
          currentVersion: currentVersion,
        );
      }

      // Clean version strings (remove 'v' prefix if present)
      final cleanCurrent = currentVersion.replaceFirst('v', '');
      final cleanLatest = versionInfo.latestVersion.replaceFirst('v', '');

      // Compare versions
      final updateAvailable = _compareVersions(cleanCurrent, cleanLatest) < 0;

      // Check if current version is below minimum supported
      bool isCritical = versionInfo.isCritical;
      if (versionInfo.minSupportedVersion != null) {
        final cleanMin = versionInfo.minSupportedVersion!.replaceFirst('v', '');
        if (_compareVersions(cleanCurrent, cleanMin) < 0) {
          isCritical = true; // Force update if below minimum
        }
      }

      await logger.info(
        'VersionCheck',
        'Update check: current=$cleanCurrent, latest=$cleanLatest, '
            'available=$updateAvailable, critical=$isCritical',
      );

      // Update last check timestamp
      await _updateLastCheckTime();

      return UpdateCheckResult(
        updateAvailable: updateAvailable,
        isCriticalUpdate: isCritical,
        versionInfo: versionInfo,
        currentVersion: currentVersion,
      );
    } catch (e, stackTrace) {
      await logger.error(
        'VersionCheck',
        'Error checking for updates: $e\n$stackTrace',
      );
      return UpdateCheckResult(updateAvailable: false, isCriticalUpdate: false);
    }
  }

  /// Fetch latest version info from Supabase
  static Future<AppVersionInfo?> _fetchLatestVersion() async {
    try {
      final response = await Supabase.instance.client
          .from('app_version')
          .select()
          .eq('platform', 'android')
          .single();

      return AppVersionInfo.fromJson(response);
    } catch (e) {
      await logger.error(
        'VersionCheck',
        'Failed to fetch version from Supabase: $e',
      );
      return null;
    }
  }

  /// Compare two semantic version strings
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure both have at least 3 parts (major.minor.patch)
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    // Compare each part
    for (int i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0; // Equal
  }

  /// Check if we should perform an update check (rate limiting)
  static Future<bool> _shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_lastCheckKey);

    if (lastCheckStr == null) return true;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return true;

    final now = DateTime.now();
    return now.difference(lastCheck) >= _checkInterval;
  }

  /// Update the last check timestamp
  static Future<void> _updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
  }

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Get current app build number
  static Future<String> getBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.buildNumber;
  }
}
