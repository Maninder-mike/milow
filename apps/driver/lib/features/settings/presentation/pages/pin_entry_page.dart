import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/core/constants/design_tokens.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key});

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final LocalAuthService _authService = LocalAuthService();
  String _pin = '';
  String? _errorMessage;
  bool _canUseBiometric = false;
  bool _hasFaceRecognition = false;
  bool _hasMultipleBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    final canCheckBiometrics = await _authService.canCheckBiometrics();
    final availableBiometrics = await _authService.getAvailableBiometrics();

    // Check biometric types
    final hasFace = availableBiometrics.contains(BiometricType.face);
    final hasFingerprint = availableBiometrics.contains(
      BiometricType.fingerprint,
    );
    final hasStrong = availableBiometrics.contains(BiometricType.strong);
    final hasWeak = availableBiometrics.contains(BiometricType.weak);

    // On Android (like OnePlus 11R), when device has both face and fingerprint,
    // it reports BiometricType.strong but system chooses which one to use.
    //
    // BiometricType.face = iOS Face ID
    // BiometricType.fingerprint = fingerprint sensor
    // BiometricType.strong/weak = Android biometric (could be face, fingerprint, or both)

    bool isFaceRecognition = false;
    bool hasMultiple = false;

    if (hasFace && !hasFingerprint) {
      // iOS Face ID or Android with only face
      isFaceRecognition = true;
    } else if (!hasFingerprint && !hasFace && (hasStrong || hasWeak)) {
      // Android device with only face unlock (no fingerprint sensor)
      isFaceRecognition = true;
    } else if (hasFingerprint && (hasStrong || hasWeak)) {
      // Android device with both fingerprint and possibly face (like OnePlus 11R)
      // Show generic "Biometric" since system decides which to use
      hasMultiple = true;
    }

    debugPrint('Biometrics: $availableBiometrics');
    debugPrint(
      'hasFace: $hasFace, hasFingerprint: $hasFingerprint, hasStrong: $hasStrong, hasWeak: $hasWeak',
    );
    debugPrint(
      'isFaceRecognition: $isFaceRecognition, hasMultiple: $hasMultiple',
    );

    setState(() {
      _canUseBiometric = isBiometricEnabled && canCheckBiometrics;
      _hasFaceRecognition = isFaceRecognition;
      _hasMultipleBiometrics = hasMultiple;
    });

    if (_canUseBiometric) {
      if (mounted) await _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final authenticated = await _authService.authenticateWithBiometrics();
    if (authenticated && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_pin.length < 4) {
        _pin += number;
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    final isValid = await _authService.verifyPin(_pin);

    if (isValid && mounted) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // App icon or logo
            Image.asset(
              'assets/images/milow_icon_beta.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            SizedBox(height: tokens.spacingXL),
            // Title
            Text(
              'Enter your PIN',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spacingM),
            Text(
              'Enter your 4-digit PIN to continue',
              style: textTheme.bodyLarge?.copyWith(color: tokens.textSecondary),
            ),
            SizedBox(height: tokens.spacingXL * 2),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFilled ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _errorMessage != null
                          ? tokens.error
                          : colorScheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: tokens.spacingL),
            // Error message
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacingXL),
                child: Text(
                  _errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(color: tokens.error),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            // Biometric button
            if (_canUseBiometric)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacingL),
                child: TextButton.icon(
                  onPressed: _authenticateWithBiometric,
                  icon: Icon(
                    _hasMultipleBiometrics
                        ? Icons.security_rounded
                        : (_hasFaceRecognition
                              ? Icons.face_rounded
                              : Icons.fingerprint_rounded),
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  label: Text(
                    _hasMultipleBiometrics
                        ? 'Use Biometric'
                        : (_hasFaceRecognition
                              ? 'Use Face ID'
                              : 'Use Fingerprint'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            // Number pad
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacingL,
                vertical: tokens.spacingXL,
              ),
              child: Column(
                children: [
                  _buildNumberRow(['1', '2', '3']),
                  SizedBox(height: tokens.spacingM),
                  _buildNumberRow(['4', '5', '6']),
                  SizedBox(height: tokens.spacingM),
                  _buildNumberRow(['7', '8', '9']),
                  SizedBox(height: tokens.spacingM),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      _buildNumberButton('0'),
                      _buildBackspaceButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) => _buildNumberButton(number)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: tokens.surfaceContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    final tokens = context.tokens;

    return InkWell(
      onTap: _onBackspacePressed,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: tokens.surfaceContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.backspace_rounded,
            color: tokens.textPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
