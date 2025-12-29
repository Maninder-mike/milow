import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/constants/design_tokens.dart';

class AppTheme {
  // Material Design 3 Color Tokens
  static const Color primaryBlue = Color(0xFF1976D2); // Material Blue 700

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ).copyWith(
          outlineVariant: const Color(0xFFE0E0E0),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1C1B1F),
          surfaceContainerLow: const Color(
            0xFFF7F7F7,
          ), // Slightly off-white for cards
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      extensions: const [DesignTokens.light],
      textTheme: GoogleFonts.notoSansGurmukhiTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.dark,
        ).copyWith(
          // Ensure dark mode outlineVariant is visible but subtle
          outlineVariant: const Color(0xFF49454F),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: const [DesignTokens.dark],
      textTheme: GoogleFonts.notoSansGurmukhiTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }
}
