import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/features/settings/presentation/pages/pin_setup_page.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final LocalAuthService _authService = LocalAuthService();
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricEnabled = await _authService.isBiometricEnabled();
    final pinEnabled = await _authService.isPinEnabled();
    final canCheckBiometrics = await _authService.canCheckBiometrics();
    final availableBiometrics = await _authService.getAvailableBiometrics();

    // Determine biometric type based on available biometrics
    String biometricType = 'Biometric';
    if (availableBiometrics.isNotEmpty) {
      // Check for biometric types
      final hasFace = availableBiometrics.contains(BiometricType.face);
      final hasFingerprint = availableBiometrics.contains(
        BiometricType.fingerprint,
      );
      final hasStrong = availableBiometrics.contains(BiometricType.strong);
      final hasWeak = availableBiometrics.contains(BiometricType.weak);

      debugPrint('Biometrics: $availableBiometrics');
      debugPrint(
        'hasFace: $hasFace, hasFingerprint: $hasFingerprint, hasStrong: $hasStrong, hasWeak: $hasWeak',
      );

      if (hasFace && !hasFingerprint) {
        // iOS Face ID or Android with only face
        biometricType = 'Face ID';
      } else if (hasFingerprint && !hasFace) {
        // Device has only fingerprint
        biometricType = 'Fingerprint';
      } else if (hasFingerprint || (hasStrong || hasWeak)) {
        // Device has fingerprint (Android shows fingerprint prompt first)
        // Or has strong/weak biometric - show generic "Biometric"
        biometricType = 'Biometric';
      }
    }

    setState(() {
      _biometricEnabled = biometricEnabled;
      _pinEnabled = pinEnabled;
      _biometricAvailable = canCheckBiometrics;
      _biometricType = biometricType;
    });
  }

  Future<void> _togglePin(bool value) async {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (value) {
      // Navigate to PIN setup
      final pin = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const PinSetupPage()),
      );

      if (pin != null) {
        await _authService.setPin(pin);
        setState(() {
          _pinEnabled = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PIN enabled successfully',
                style: textTheme.bodyMedium,
              ),
              backgroundColor: tokens.success,
            ),
          );
        }
      }
    } else {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Disable PIN?',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'You will need to login with email and password next time.',
            style: textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: textTheme.labelLarge?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Disable',
                style: textTheme.labelLarge?.copyWith(color: tokens.error),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _authService.removePin();
        setState(() {
          _pinEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PIN disabled', style: textTheme.bodyMedium),
            ),
          );
        }
      }
    }
  }

  Future<void> _changePin() async {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const PinSetupPage(isChanging: true),
      ),
    );

    if (pin != null) {
      await _authService.setPin(pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PIN changed successfully',
              style: textTheme.bodyMedium,
            ),
            backgroundColor: tokens.success,
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Biometric authentication not available on this device',
            style: textTheme.bodyMedium,
          ),
          backgroundColor: tokens.error,
        ),
      );
      return;
    }

    if (value) {
      // Test biometric authentication first
      final authenticated = await _authService.authenticateWithBiometrics();
      if (authenticated) {
        await _authService.setBiometricEnabled(true);
        setState(() {
          _biometricEnabled = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$_biometricType enabled successfully',
                style: textTheme.bodyMedium,
              ),
              backgroundColor: tokens.success,
            ),
          );
        }
      }
    } else {
      await _authService.setBiometricEnabled(false);
      setState(() {
        _biometricEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_biometricType disabled',
              style: textTheme.bodyMedium,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy & Security',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: tokens.spacingM),
            // Authentication Section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacingM,
                vertical: tokens.spacingS,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AUTHENTICATION',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: tokens.spacingM),
              decoration: BoxDecoration(
                color: tokens.surfaceContainer,
                borderRadius: BorderRadius.circular(tokens.shapeL),
              ),
              child: Column(
                children: [
                  // PIN Code
                  Padding(
                    padding: EdgeInsets.all(tokens.spacingM),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PIN Code',
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              SizedBox(height: tokens.spacingXS),
                              Text(
                                'Use a 4-digit PIN to login',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _pinEnabled,
                          onChanged: _togglePin,
                          activeTrackColor: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  // Change PIN button (only show if PIN is enabled)
                  if (_pinEnabled)
                    Column(
                      children: [
                        Divider(height: 1, color: tokens.subtleBorderColor),
                        InkWell(
                          onTap: _changePin,
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spacingM),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change PIN',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  Divider(height: 1, color: tokens.subtleBorderColor),
                  // Biometric Authentication
                  Padding(
                    padding: EdgeInsets.all(tokens.spacingM),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _biometricType,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  if (!_biometricAvailable) ...[
                                    SizedBox(width: tokens.spacingS),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: tokens.spacingS,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.textTertiary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          tokens.shapeXS,
                                        ),
                                      ),
                                      child: Text(
                                        'Not Available',
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: tokens.spacingXS),
                              Text(
                                _biometricAvailable
                                    ? 'Use ${_biometricType.toLowerCase()} to login'
                                    : 'Not available on this device',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _biometricEnabled,
                          onChanged: _biometricAvailable
                              ? _toggleBiometric
                              : null,
                          activeThumbColor: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacingL),
            // Info Card
            Container(
              margin: EdgeInsets.symmetric(horizontal: tokens.spacingM),
              padding: EdgeInsets.all(tokens.spacingM),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(tokens.shapeM),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: Text(
                      'Enable PIN or biometric authentication to avoid repeated email logins. Your session will stay active and secure.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
