import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/local_auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    final canCheckBiometrics = await _authService.canCheckBiometrics();

    setState(() {
      _canUseBiometric = isBiometricEnabled && canCheckBiometrics;
    });

    // Auto-trigger biometric if enabled
    if (_canUseBiometric) {
      _authenticateWithBiometric();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // App icon or logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 64,
                color: Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 32),
            // Title
            Text(
              'Enter your PIN',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your 4-digit PIN to continue',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 48),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFilled
                        ? const Color(0xFF007AFF)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _errorMessage != null
                          ? Colors.red
                          : const Color(0xFF007AFF),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            // Biometric button
            if (_canUseBiometric)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton.icon(
                  onPressed: _authenticateWithBiometric,
                  icon: const Icon(
                    Icons.fingerprint,
                    color: Color(0xFF007AFF),
                    size: 28,
                  ),
                  label: Text(
                    'Use Biometric',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  _buildNumberRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildNumberRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildNumberRow(['7', '8', '9']),
                  const SizedBox(height: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: buttonColor,
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
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final iconColor = isDark ? Colors.white : const Color(0xFF101828);

    return InkWell(
      onTap: _onBackspacePressed,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: buttonColor,
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
          child: Icon(Icons.backspace_outlined, color: iconColor, size: 28),
        ),
      ),
    );
  }
}
