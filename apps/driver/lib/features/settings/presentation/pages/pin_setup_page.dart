import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

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
          widget.isChanging ? 'Change PIN' : 'Set Up PIN',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
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
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spacingM),
          Text(
            _isConfirming ? 'Enter the same PIN again' : 'Enter a 4-digit PIN',
            style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          SizedBox(height: tokens.spacingXL),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final currentPin = _isConfirming ? _confirmPin : _pin;
              final isFilled = index < currentPin.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: tokens.spacingS + 4),
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
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.error,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Spacer(),
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
            style: textTheme.headlineMedium?.copyWith(
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
