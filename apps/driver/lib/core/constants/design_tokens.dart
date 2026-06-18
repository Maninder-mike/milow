import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

/// DesignTokens encapsulates spacing, radii, elevations and shared colors.
/// Added as a ThemeExtension so we can access via `Theme.of(context).extension<DesignTokens>()`
///
/// Usage:
/// ```dart
/// final tokens = Theme.of(context).extension<DesignTokens>()!;
/// Container(color: tokens.surfaceContainer);
/// ```
class DesignTokens extends ThemeExtension<DesignTokens> {
  // ============= SPACING (8dp grid) =============
  final double spacingXS;
  final double spacingS;
  final double spacingM;
  final double spacingL;
  final double spacingXL;

  // ============= M3 SHAPE SCALE =============
  /// Extra small corners (e.g., chips, small buttons)
  final double shapeXS;

  /// Small corners (e.g., text fields, cards)
  final double shapeS;

  /// Medium corners (e.g., dialogs, action sheets)
  final double shapeM;

  /// Large corners (e.g., FABs, bottom sheets)
  final double shapeL;

  /// Extra large corners (e.g., hero cards)
  final double shapeXL;

  /// Button corner radius (20px)
  final double shapeButton;

  /// Full/circular corners
  final double shapeFull;

  // Legacy aliases for compatibility
  double get radiusS => shapeS;
  double get radiusM => shapeM;
  double get radiusL => shapeL;
  double get radiusXL => shapeXL;

  // ============= M3 ELEVATION LEVELS =============
  /// Level 0 - Surface (0dp)
  final double elevationLevel0;

  /// Level 1 - Raised surfaces (1dp)
  final double elevationLevel1;

  /// Level 2 - Cards, menus (3dp)
  final double elevationLevel2;

  /// Level 3 - Dialogs (6dp)
  final double elevationLevel3;

  /// Level 4 - Modals (8dp)
  final double elevationLevel4;

  /// Level 5 - FAB pressed (12dp)
  final double elevationLevel5;

  // Legacy alias
  double get cardElevation => elevationLevel0;

  // ============= SURFACE COLORS =============
  /// Primary text color (e.g., titles, headings)
  final Color textPrimary;

  /// Secondary text color (e.g., subtitles, descriptions)
  final Color textSecondary;

  /// Tertiary/muted text color (e.g., hints, labels)
  final Color textTertiary;

  /// Container background (cards, dialogs)
  final Color surfaceContainer;

  /// Elevated container background
  final Color surfaceContainerHigh;

  /// Alternative scaffold background
  final Color scaffoldAltBackground;

  /// Subtle border color for cards, inputs
  final Color subtleBorderColor;

  /// Section label color
  final Color sectionLabelColor;

  // ============= SEMANTIC COLORS =============
  /// Success color (e.g., positive trends, completed)
  final Color success;

  /// Success container/background
  final Color successContainer;

  /// Error/danger color (e.g., negative trends, alerts)
  final Color error;

  /// Error container/background
  final Color errorContainer;

  /// Warning color
  final Color warning;

  /// Warning container/background
  final Color warningContainer;

  /// Info color
  final Color info;

  /// Info container/background
  final Color infoContainer;

  // ============= INPUT COLORS =============
  /// Input field background
  final Color inputBackground;

  /// Input field border
  final Color inputBorder;

  /// Input field focused border
  final Color inputFocusedBorder;

  /// Disabled element color
  final Color disabled;

  // ============= GLASSMORPHISM =============
  /// Blur sigma for glass effects
  final double glassBlur;

  /// Opacity for glass background
  final double glassOpacity;

  /// Opacity for glass border
  final double glassBorderOpacity;

  // ============= ANIMATIONS =============
  /// Standard transition duration
  final Duration transitionDuration;

  /// Standard transition curve
  final Curve transitionCurve;

  const DesignTokens({
    required this.spacingXS,
    required this.spacingS,
    required this.spacingM,
    required this.spacingL,
    required this.spacingXL,
    // M3 Shape Scale
    required this.shapeXS,
    required this.shapeS,
    required this.shapeM,
    required this.shapeL,
    required this.shapeXL,
    required this.shapeButton,
    required this.shapeFull,
    // M3 Elevation Levels
    required this.elevationLevel0,
    required this.elevationLevel1,
    required this.elevationLevel2,
    required this.elevationLevel3,
    required this.elevationLevel4,
    required this.elevationLevel5,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.scaffoldAltBackground,
    required this.subtleBorderColor,
    required this.sectionLabelColor,
    required this.success,
    required this.successContainer,
    required this.error,
    required this.errorContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputFocusedBorder,
    required this.disabled,
    required this.glassBlur,
    required this.glassOpacity,
    required this.glassBorderOpacity,
    required this.transitionDuration,
    required this.transitionCurve,
  });

  static const light = DesignTokens(
    // Spacing (8dp grid)
    spacingXS: 4,
    spacingS: 8,
    spacingM: 16,
    spacingL: 24,
    spacingXL: 32,
    // M3 Shape Scale (corner radii)
    shapeXS: 4, // Extra small (chips, small buttons)
    shapeS: 8, // Small (text fields, small cards)
    shapeM: 12, // Medium (cards, dialogs)
    shapeL: 16, // Large (FAB, nav drawer)
    shapeXL: 28, // Extra large (dialogs, hero cards)
    shapeButton: 20, // Standard button radius
    shapeFull: 999, // Circular/pill
    // M3 Elevation Levels
    elevationLevel0: 0, // Surface
    elevationLevel1: 1, // Raised surfaces
    elevationLevel2: 3, // Cards, menus
    elevationLevel3: 6, // Dialogs
    elevationLevel4: 8, // Modals
    elevationLevel5: 12, // FAB pressed
    // Text
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF667085),
    textTertiary: Color(0xFF98A2B3),
    // Surfaces
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceContainerHigh: Color(0xFFF9FAFB),
    scaffoldAltBackground: Color(0xFFF9FAFB),
    subtleBorderColor: Color(0xFFE5E7EB),
    sectionLabelColor: Color(0xFF98A2B3),
    // Semantic
    success: Color(0xFF10B981),
    successContainer: Color(0xFFD1FAE5),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFFFEE2E2),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFFFEF3C7),
    info: Color(0xFF3B82F6),
    infoContainer: Color(0xFFDBEAFE),
    // Inputs
    inputBackground: Color(0xFFF9FAFB),
    inputBorder: Color(0xFFE5E7EB),
    inputFocusedBorder: Color(0xFF1976D2),
    disabled: Color(0xFFE5E5E5),
    glassBlur: 10.0,
    glassOpacity: 0.1,
    glassBorderOpacity: 0.2,
    transitionDuration: Duration(milliseconds: 300),
    transitionCurve: Curves.easeInOut,
  );

  static const dark = DesignTokens(
    // Spacing (8dp grid)
    spacingXS: 4,
    spacingS: 8,
    spacingM: 16,
    spacingL: 24,
    spacingXL: 32,
    // M3 Shape Scale (corner radii)
    shapeXS: 4, // Extra small (chips, small buttons)
    shapeS: 8, // Small (text fields, small cards)
    shapeM: 12, // Medium (cards, dialogs)
    shapeL: 16, // Large (FAB, nav drawer)
    shapeXL: 28, // Extra large (dialogs, hero cards)
    shapeButton: 20, // Standard button radius
    shapeFull: 999, // Circular/pill
    // M3 Elevation Levels
    elevationLevel0: 0, // Surface
    elevationLevel1: 1, // Raised surfaces
    elevationLevel2: 3, // Cards, menus
    elevationLevel3: 6, // Dialogs
    elevationLevel4: 8, // Modals
    elevationLevel5: 12, // FAB pressed
    // Text
    textPrimary: Color(0xFFF9FAFB), // Gray 50
    textSecondary: Color(0xFF9CA3AF), // Gray 400
    textTertiary: Color(0xFF6B7280), // Gray 500
    // Surfaces
    surfaceContainer: Color(0xFF111827), // Gray 900 (Rich Slate)
    surfaceContainerHigh: Color(0xFF1F2937), // Gray 800
    scaffoldAltBackground: Color(0xFF0B0F19), // Rich Deep Background
    subtleBorderColor: Color(0xFF374151), // Gray 700
    sectionLabelColor: Color(0xFF9CA3AF),
    // Semantic - Desaturated for dark mode
    success: Color(0xFF34D399), // Emerald 400
    successContainer: Color(0xFF064E3B), // Emerald 900
    error: Color(0xFFF87171), // Red 400
    errorContainer: Color(0xFF7F1D1D), // Red 900
    warning: Color(0xFFFBBF24), // Amber 400
    warningContainer: Color(0xFF78350F), // Amber 900
    info: Color(0xFF60A5FA), // Blue 400
    infoContainer: Color(0xFF1E3A8A), // Blue 900
    // Inputs
    inputBackground: Color(0xFF1F2937), // Matches surfaceContainerHigh
    inputBorder: Color(0xFF374151),
    inputFocusedBorder: Color(0xFF60A5FA), // Blue 400
    disabled: Color(0xFF374151),
    glassBlur: 20.0,
    glassOpacity: 0.15,
    glassBorderOpacity: 0.1,
    transitionDuration: Duration(milliseconds: 300),
    transitionCurve: Curves.easeInOut,
  );

  @override
  ThemeExtension<DesignTokens> copyWith({
    double? spacingXS,
    double? spacingS,
    double? spacingM,
    double? spacingL,
    double? spacingXL,
    double? shapeXS,
    double? shapeS,
    double? shapeM,
    double? shapeL,
    double? shapeXL,
    double? shapeButton,
    double? shapeFull,
    double? elevationLevel0,
    double? elevationLevel1,
    double? elevationLevel2,
    double? elevationLevel3,
    double? elevationLevel4,
    double? elevationLevel5,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? scaffoldAltBackground,
    Color? subtleBorderColor,
    Color? sectionLabelColor,
    Color? success,
    Color? successContainer,
    Color? error,
    Color? errorContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputFocusedBorder,
    Color? disabled,
    double? glassBlur,
    double? glassOpacity,
    double? glassBorderOpacity,
    Duration? transitionDuration,
    Curve? transitionCurve,
  }) {
    return DesignTokens(
      spacingXS: spacingXS ?? this.spacingXS,
      spacingS: spacingS ?? this.spacingS,
      spacingM: spacingM ?? this.spacingM,
      spacingL: spacingL ?? this.spacingL,
      spacingXL: spacingXL ?? this.spacingXL,
      shapeXS: shapeXS ?? this.shapeXS,
      shapeS: shapeS ?? this.shapeS,
      shapeM: shapeM ?? this.shapeM,
      shapeL: shapeL ?? this.shapeL,
      shapeXL: shapeXL ?? this.shapeXL,
      shapeButton: shapeButton ?? this.shapeButton,
      shapeFull: shapeFull ?? this.shapeFull,
      elevationLevel0: elevationLevel0 ?? this.elevationLevel0,
      elevationLevel1: elevationLevel1 ?? this.elevationLevel1,
      elevationLevel2: elevationLevel2 ?? this.elevationLevel2,
      elevationLevel3: elevationLevel3 ?? this.elevationLevel3,
      elevationLevel4: elevationLevel4 ?? this.elevationLevel4,
      elevationLevel5: elevationLevel5 ?? this.elevationLevel5,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      scaffoldAltBackground:
          scaffoldAltBackground ?? this.scaffoldAltBackground,
      subtleBorderColor: subtleBorderColor ?? this.subtleBorderColor,
      sectionLabelColor: sectionLabelColor ?? this.sectionLabelColor,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocusedBorder: inputFocusedBorder ?? this.inputFocusedBorder,
      disabled: disabled ?? this.disabled,
      glassBlur: glassBlur ?? this.glassBlur,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
    );
  }

  @override
  ThemeExtension<DesignTokens> lerp(
    covariant ThemeExtension<DesignTokens>? other,
    double t,
  ) {
    if (other is! DesignTokens) return this;
    return DesignTokens(
      spacingXS: lerpDouble(spacingXS, other.spacingXS, t) ?? spacingXS,
      spacingS: lerpDouble(spacingS, other.spacingS, t) ?? spacingS,
      spacingM: lerpDouble(spacingM, other.spacingM, t) ?? spacingM,
      spacingL: lerpDouble(spacingL, other.spacingL, t) ?? spacingL,
      spacingXL: lerpDouble(spacingXL, other.spacingXL, t) ?? spacingXL,
      shapeXS: lerpDouble(shapeXS, other.shapeXS, t) ?? shapeXS,
      shapeS: lerpDouble(shapeS, other.shapeS, t) ?? shapeS,
      shapeM: lerpDouble(shapeM, other.shapeM, t) ?? shapeM,
      shapeL: lerpDouble(shapeL, other.shapeL, t) ?? shapeL,
      shapeXL: lerpDouble(shapeXL, other.shapeXL, t) ?? shapeXL,
      shapeButton: lerpDouble(shapeButton, other.shapeButton, t) ?? shapeButton,
      shapeFull: lerpDouble(shapeFull, other.shapeFull, t) ?? shapeFull,
      elevationLevel0: lerpDouble(elevationLevel0, other.elevationLevel0, t) ?? elevationLevel0,
      elevationLevel1: lerpDouble(elevationLevel1, other.elevationLevel1, t) ?? elevationLevel1,
      elevationLevel2: lerpDouble(elevationLevel2, other.elevationLevel2, t) ?? elevationLevel2,
      elevationLevel3: lerpDouble(elevationLevel3, other.elevationLevel3, t) ?? elevationLevel3,
      elevationLevel4: lerpDouble(elevationLevel4, other.elevationLevel4, t) ?? elevationLevel4,
      elevationLevel5: lerpDouble(elevationLevel5, other.elevationLevel5, t) ?? elevationLevel5,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t) ?? glassBlur,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      glassBorderOpacity: lerpDouble(glassBorderOpacity, other.glassBorderOpacity, t) ?? glassBorderOpacity,
      transitionDuration: t < 0.5 ? transitionDuration : other.transitionDuration,
      transitionCurve: t < 0.5 ? transitionCurve : other.transitionCurve,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t) ??
          surfaceContainer,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t) ??
          surfaceContainerHigh,
      scaffoldAltBackground:
          Color.lerp(scaffoldAltBackground, other.scaffoldAltBackground, t) ??
          scaffoldAltBackground,
      subtleBorderColor:
          Color.lerp(subtleBorderColor, other.subtleBorderColor, t) ??
          subtleBorderColor,
      sectionLabelColor:
          Color.lerp(sectionLabelColor, other.sectionLabelColor, t) ??
          sectionLabelColor,
      success: Color.lerp(success, other.success, t) ?? success,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      error: Color.lerp(error, other.error, t) ?? error,
      errorContainer:
          Color.lerp(errorContainer, other.errorContainer, t) ?? errorContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
      info: Color.lerp(info, other.info, t) ?? info,
      infoContainer:
          Color.lerp(infoContainer, other.infoContainer, t) ?? infoContainer,
      inputBackground:
          Color.lerp(inputBackground, other.inputBackground, t) ??
          inputBackground,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t) ?? inputBorder,
      inputFocusedBorder:
          Color.lerp(inputFocusedBorder, other.inputFocusedBorder, t) ??
          inputFocusedBorder,
      disabled: Color.lerp(disabled, other.disabled, t) ?? disabled,
    );
  }
}

/// Extension for easy access to DesignTokens
extension DesignTokensExtension on BuildContext {
  DesignTokens get tokens => Theme.of(this).extension<DesignTokens>()!;
}
