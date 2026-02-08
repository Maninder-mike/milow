import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_theme/system_theme.dart';

class AppTheme {
  // Premium Dark Palette
  static const Color _darkBackground = Color(0xFF13161C); // Deep Slate
  static const Color _darkCard = Color(0xFF1F2937); // Lighter Slate
  static const Color _darkBorder = Color(0x1FFFFFFF); // Subtle White Border

  // Premium Light Palette
  static const Color _lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color _lightCard = Color(0xFFFFFFFF); // Pure White
  static const Color _lightBorder = Color(0xFFE2E8F0); // Slate 200

  // Accent Color (Professional Blue/Slate)
  static AccentColor get accentColor {
    // Fallback if system accent is not available or we prefer our own
    return SystemTheme.accentColor.accent.toAccentColor();
  }

  static FluentThemeData get light {
    return FluentThemeData(
      accentColor: accentColor,
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightCard,
      fontFamily: GoogleFonts.outfit().fontFamily,

      // Enhance Sidebar Transparency/Mica Effect
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: _lightBackground.withValues(
          alpha: 0.85,
        ), // Slightly transparent for Mica feel
        overlayBackgroundColor: _lightCard,
        highlightColor: accentColor.withValues(alpha: 0.05),
      ),

      radioButtonTheme: RadioButtonThemeData(
        checkedDecoration: WidgetStateProperty.resolveWith((states) {
          return BoxDecoration(color: accentColor, shape: BoxShape.circle);
        }),
      ),

      // Card & Surface Styling
      resources: ResourceDictionary.light(
        cardBackgroundFillColorDefault: _lightCard,
        dividerStrokeColorDefault: _lightBorder,
        controlFillColorDefault: _lightCard,
        layerFillColorDefault: _lightCard,
        solidBackgroundFillColorBase: _lightBackground,
        solidBackgroundFillColorSecondary: const Color(0xFFF1F5F9), // Slate 100
        solidBackgroundFillColorTertiary: const Color(0xFFE2E8F0), // Slate 200
      ),
    );
  }

  static FluentThemeData get dark {
    return FluentThemeData(
      accentColor: accentColor,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkCard,
      fontFamily: GoogleFonts.outfit().fontFamily,

      // Enhance Sidebar Transparency/Mica Effect
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: _darkBackground.withValues(
          alpha: 0.8,
        ), // Slightly transparent for Mica feel
        overlayBackgroundColor: _darkCard,
        highlightColor: accentColor.withValues(alpha: 0.1),
      ),

      // Card & Surface Styling
      resources: ResourceDictionary.dark(
        cardBackgroundFillColorDefault: _darkCard,
        dividerStrokeColorDefault: _darkBorder,
        controlFillColorDefault: _darkCard,
        layerFillColorDefault: _darkCard,
        solidBackgroundFillColorBase: _darkBackground,
        solidBackgroundFillColorSecondary: const Color(
          0xFF1F2937,
        ), // Matches _darkCard
        solidBackgroundFillColorTertiary: const Color(0xFF374151), // Slate 700
      ),
    );
  }
}
