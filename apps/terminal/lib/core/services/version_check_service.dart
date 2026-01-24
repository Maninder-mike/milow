import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

enum UpdateStatus { latest, optionalUpdate, forceUpdate }

class VersionCheckService {
  final FirebaseRemoteConfig _remoteConfig;

  VersionCheckService(this._remoteConfig);

  static const String _keyMinVersion = 'terminal_min_version';
  static const String _keyLatestVersion = 'terminal_latest_version';

  Future<UpdateStatus> checkUpdateStatus() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Ensure config is fresh
      await _remoteConfig.fetchAndActivate();

      final minVersion = _remoteConfig.getString(_keyMinVersion);
      final latestVersion = _remoteConfig.getString(_keyLatestVersion);

      if (minVersion.isNotEmpty &&
          _isVersionLower(currentVersion, minVersion)) {
        return UpdateStatus.forceUpdate;
      }

      if (latestVersion.isNotEmpty &&
          _isVersionLower(currentVersion, latestVersion)) {
        return UpdateStatus.optionalUpdate;
      }

      return UpdateStatus.latest;
    } catch (e) {
      debugPrint('Error checking version status: $e');
      // On error, default to no update to prevent blocking user in case of network issues
      return UpdateStatus.latest;
    }
  }

  bool _isVersionLower(String current, String target) {
    try {
      // Clean versions (remove +build number if present)
      final currentClean = current.split('+').first;
      final targetClean = target.split('+').first;

      final currentParts = currentClean.split('.').map(int.parse).toList();
      final targetParts = targetClean.split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final t = i < targetParts.length ? targetParts[i] : 0;

        if (c < t) return true;
        if (c > t) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error parsing version: $e');
      return false;
    }
  }
}
