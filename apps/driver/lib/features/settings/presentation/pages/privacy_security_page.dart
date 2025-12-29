import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
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
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: Colors.green,
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'You will need to login with email and password next time.',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF667085)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Disable',
                style: GoogleFonts.outfit(color: Colors.red),
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
              content: Text('PIN disabled', style: GoogleFonts.outfit()),
            ),
          );
        }
      }
    }
  }

  Future<void> _changePin() async {
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
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Biometric authentication not available on this device',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.red,
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
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: Colors.green,
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
              style: GoogleFonts.outfit(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy & Security',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Authentication Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AUTHENTICATION',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF98A2B3),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // PIN Code
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PIN Code',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use a 4-digit PIN to login',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _pinEnabled,
                          onChanged: _togglePin,
                          activeThumbColor: const Color(0xFF007AFF),
                        ),
                      ],
                    ),
                  ),
                  // Change PIN button (only show if PIN is enabled)
                  if (_pinEnabled)
                    Column(
                      children: [
                        Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFE5E7EB),
                        ),
                        InkWell(
                          onTap: _changePin,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change PIN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: const Color(0xFF007AFF),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Color(0xFF007AFF),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  // Divider
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFE5E7EB),
                  ),
                  // Biometric Authentication
                  Padding(
                    padding: const EdgeInsets.all(16.0),
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
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                  if (!_biometricAvailable) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF98A2B3,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Not Available',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF98A2B3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _biometricAvailable
                                    ? 'Use ${_biometricType.toLowerCase()} to login'
                                    : 'Not available on this device',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: secondaryTextColor,
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
                          activeThumbColor: const Color(0xFF007AFF),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable PIN or biometric authentication to avoid repeated email logins. Your session will stay active and secure.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF007AFF),
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
