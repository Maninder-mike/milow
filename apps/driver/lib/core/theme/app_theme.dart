import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// Material 3 Expressive Theme Configuration
///
/// Implements M3 Expressive design principles:
/// - Vibrant color schemes with expanded color roles
/// - Motion-physics system for fluid animations
/// - Enhanced visual hierarchy through color contrast
/// - Dynamic color support (via DynamicColorBuilder in main.dart)
///
/// Reference: https://m3.material.io/blog/building-with-m3-expressive
class AppTheme {
  // M3 Expressive: Vibrant seed color for dynamic color generation
  static const Color primaryBlue = Color(0xFF1976D2); // Material Blue 700

  // M3 Expressive: Tertiary accent for additional visual interest
  static const Color tertiaryAccent = Color(0xFF7C4DFF); // Deep Purple A200

  // M3 Expressive: Emphasis motion curves
  static const Curve expressiveEmphasizedCurve = Curves.easeOutExpo;
  static const Curve expressiveStandardCurve = Curves.easeInOutCubicEmphasized;

  // M3 Expressive: Motion durations
  static const Duration durationShort = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationLong = Duration(milliseconds: 500);
  static const Duration durationEmphasis = Duration(milliseconds: 700);

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
          // M3 Expressive: Use expanded color roles
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        ).copyWith(
          // M3 Expressive: Enhanced contrast with tertiary colors
          tertiary: tertiaryAccent,
          outlineVariant: const Color(0xFFE0E0E0),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1C1B1F),
          surfaceContainerLow: const Color(0xFFF7F7F7),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      extensions: const [DesignTokens.light],
      // M3 Typography Scale
      textTheme: _buildTextTheme(Brightness.light),
      // M3 Expressive: Page transitions with emphasis motion
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // M3 Expressive: Elevated buttons with rounded corners
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // M3 Expressive: Cards with subtle elevation
      cardTheme: const CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      // M3 Expressive: Chips with expressive shape
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // M3 Expressive: Dialog with increased corner radius
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      // M3 Expressive: Bottom sheet with drag handle
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: Color(0xFFE0E0E0),
        dragHandleSize: Size(32, 4),
      ),
      // M3 Expressive: Progress indicators with rounded stroke caps
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.dark,
          // M3 Expressive: Use vibrant variant for rich dark colors
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        ).copyWith(
          // M3 Expressive: Tertiary for emphasis in dark mode
          tertiary: tertiaryAccent.withAlpha(230),
          outlineVariant: const Color(0xFF49454F),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: const [DesignTokens.dark],
      // M3 Typography Scale
      textTheme: _buildTextTheme(Brightness.dark),
      // M3 Expressive: Page transitions with emphasis motion
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // M3 Expressive: Elevated buttons with rounded corners
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // M3 Expressive: Cards with subtle elevation
      cardTheme: const CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      // M3 Expressive: Chips with expressive shape
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // M3 Expressive: Dialog with increased corner radius
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      // M3 Expressive: Bottom sheet with drag handle
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: Color(0xFF49454F),
        dragHandleSize: Size(32, 4),
      ),
      // M3 Expressive: Progress indicators with rounded stroke caps
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  /// Build M3 Typography Scale
  /// Reference: https://m3.material.io/styles/typography/applying-type
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0xFF1C1B1F)
        : Colors.white;

    return TextTheme(
      // Display styles - for large, short text
      displayLarge: GoogleFonts.outfit(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 64 / 57,
        letterSpacing: -0.25,
        color: color,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 52 / 45,
        letterSpacing: 0,
        color: color,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 44 / 36,
        letterSpacing: 0,
        color: color,
      ),
      // Headline styles - for high-emphasis text
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 40 / 32,
        letterSpacing: 0,
        color: color,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 36 / 28,
        letterSpacing: 0,
        color: color,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 32 / 24,
        letterSpacing: 0,
        color: color,
      ),
      // Title styles - for medium-emphasis text
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        height: 28 / 22,
        letterSpacing: 0,
        color: color,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        letterSpacing: 0.15,
        color: color,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: color,
      ),
      // Label styles - for small text in components
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: color,
      ),
      labelMedium: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.5,
        color: color,
      ),
      labelSmall: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.5,
        color: color,
      ),
      // Body styles - for long-form text
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0.5,
        color: color,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0.25,
        color: color,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: 0.4,
        color: color,
      ),
    );
  }
}
