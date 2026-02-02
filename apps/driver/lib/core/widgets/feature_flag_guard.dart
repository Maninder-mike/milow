import 'package:flutter/material.dart';
import 'package:milow/core/services/driver_remote_config_service.dart';

/// A widget that conditionally builds [child] based on a feature flag.
///
/// If the feature flag [flagKey] is true, [child] is rendered.
/// Otherwise, [fallback] is rendered (defaults to [SizedBox.shrink]).
class FeatureFlagGuard extends StatelessWidget {
  final String flagKey;
  final Widget child;
  final Widget fallback;

  const FeatureFlagGuard({
    required this.flagKey,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = DriverRemoteConfigService.instance.getBool(flagKey);

    if (isEnabled) {
      return child;
    }

    return fallback;
  }
}
