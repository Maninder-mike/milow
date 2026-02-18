import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Forces text to be uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Alphanumeric and Uppercase only. Good for License Plates and IDs.
/// Allows spaces and hyphens for readability if needed, but for strict plates usually just alphanumeric.
class LicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Uppercase first
    final uppercased = newValue.text.toUpperCase();

    // Allow A-Z, 0-9, and space/dash
    final regex = RegExp(r'^[A-Z0-9 -]*$');

    if (!regex.hasMatch(uppercased)) {
      return oldValue;
    }

    return TextEditingValue(text: uppercased, selection: newValue.selection);
  }
}

/// VIN Formatter: 17 characters max, Uppercase, Alphanumeric (excluding I, O, Q is standard but we'll just soft enforce or warn).
/// For now, strict alphanumeric + uppercase.
class VinFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > 17) return oldValue;

    final uppercased = newValue.text.toUpperCase();
    // Valid VIN chars: A-H, J-N, P, R-Z, 0-9. (No I, O, Q)
    // For friendliness, we might just map I->1, O->0, Q->0 or just reject.
    // Let's just enforce alphanumeric for now to be safe but simpler.
    final regex = RegExp(r'^[A-Z0-9]*$');

    if (!regex.hasMatch(uppercased)) {
      return oldValue;
    }

    return TextEditingValue(text: uppercased, selection: newValue.selection);
  }
}

/// Formats currency inputs with 2 decimal places.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Allow only digits and one decimal point
    final regEx = RegExp(r'^\d*\.?\d{0,2}');
    if (!regEx.hasMatch(newValue.text)) {
      return oldValue;
    }

    // Prevent multiple decimals
    if (newValue.text.indexOf('.') != newValue.text.lastIndexOf('.')) {
      return oldValue;
    }

    return newValue;
  }
}

/// Adds thousands separators to numbers (e.g., 1,234,567 or 1,234.56).
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final bool allowFraction;
  final NumberFormat _formatter;

  ThousandsSeparatorInputFormatter({this.allowFraction = false})
    : _formatter = allowFraction
          ? NumberFormat.decimalPattern()
          : NumberFormat.decimalPattern();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Handle decimal point input for fractional support
    if (allowFraction && newValue.text.endsWith('.')) {
      // If just typed a dot, allow it if valid
      final parts = newValue.text.split('.');
      if (parts.length > 2) return oldValue; // Multiple dots
      // Check if integer part is valid formatted number
      // We can just return newValue here to let user type next digit
      return newValue;
    }

    // Remove non-digit and non-decimal point chars
    String newTextRaw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');

    // If starts with point, add 0
    if (newTextRaw.startsWith('.')) {
      newTextRaw = '0$newTextRaw';
    }

    // Prevent multiple dots
    if (newTextRaw.indexOf('.') != newTextRaw.lastIndexOf('.')) {
      return oldValue;
    }

    // Split into integer and fraction
    final parts = newTextRaw.split('.');
    String integerPart = parts[0];
    final String? fractionalPart = parts.length > 1 ? parts[1] : null;

    // If empty after strip, back to empty
    if (integerPart.isEmpty && fractionalPart == null) {
      return newValue.copyWith(text: '');
    }

    // Format integer part
    try {
      if (integerPart.isNotEmpty) {
        final number = int.parse(integerPart);
        integerPart = _formatter.format(number);
      } else {
        integerPart = '0';
      }

      String newTextFormatted = integerPart;
      if (allowFraction && parts.length > 1) {
        newTextFormatted += '.$fractionalPart';
      }

      return TextEditingValue(
        text: newTextFormatted,
        selection: TextSelection.collapsed(offset: newTextFormatted.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}
