import 'package:package_info_plus/package_info_plus.dart';
import 'package:milow/core/services/driver_remote_config_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:pub_semver/pub_semver.dart';

class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  /// Returns true if the current app version is less than the minimum supported version
  Future<bool> isUpdateRequired() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;

      final minVersionStr =
          DriverRemoteConfigService.instance.forceUpdateVersion;

      if (minVersionStr.isEmpty || minVersionStr == '0.0.0') return false;

      final currentVersion = Version.parse(currentVersionStr);
      final minVersion = Version.parse(minVersionStr);

      if (currentVersion < minVersion) {
        AppLogger.warning(
          'Force Update Required: Current=$currentVersion, Min=$minVersion',
        );
        return true;
      }

      return false;
    } catch (e, stack) {
      AppLogger.error('Failed to check version', error: e, stackTrace: stack);
      // Fail safe: don't block user if check fails
      return false;
    }
  }
}
