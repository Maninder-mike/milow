import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinSetupPage extends StatefulWidget {
  final bool isChanging;

  const PinSetupPage({super.key, this.isChanging = false});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onNumberPressed(String number) {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          if (_confirmPin.length == 4) {
            _validatePin();
          }
        }
      } else {
        if (_pin.length < 4) {
          _pin += number;
          if (_pin.length == 4) {
            _isConfirming = true;
            _errorMessage = null;
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
      _errorMessage = null;
    });
  }

  void _validatePin() {
    if (_pin == _confirmPin) {
      Navigator.pop(context, _pin);
    } else {
      setState(() {
        _errorMessage = 'PINs do not match. Try again.';
        _confirmPin = '';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _pin = '';
            _isConfirming = false;
            _errorMessage = null;
          });
        }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isChanging ? 'Change PIN' : 'Set Up PIN',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Title
          Text(
            _isConfirming ? 'Confirm your PIN' : 'Create a PIN',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isConfirming ? 'Enter the same PIN again' : 'Enter a 4-digit PIN',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 48),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final currentPin = _isConfirming ? _confirmPin : _pin;
              final isFilled = index < currentPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isFilled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
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
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const Spacer(),
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
            style: GoogleFonts.outfit(
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
          child: Icon(Icons.backspace_rounded, color: iconColor, size: 28),
        ),
      ),
    );
  }
}
