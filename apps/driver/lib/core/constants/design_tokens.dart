import 'package:flutter/material.dart';

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
    shapeFull: 999, // Circular/pill
    // M3 Elevation Levels
    elevationLevel0: 0, // Surface
    elevationLevel1: 1, // Raised surfaces
    elevationLevel2: 3, // Cards, menus
    elevationLevel3: 6, // Dialogs
    elevationLevel4: 8, // Modals
    elevationLevel5: 12, // FAB pressed
    // Text
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFADBBC9),
    textTertiary: Color(0xFF9CA3AF),
    // Surfaces
    surfaceContainer: Color(0xFF1E1E1E),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    scaffoldAltBackground: Color(0xFF121212),
    subtleBorderColor: Color(0xFF3A3A3A),
    sectionLabelColor: Color(0xFF9CA3AF),
    // Semantic
    success: Color(0xFF10B981),
    successContainer: Color(0xFF064E3B),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFF7F1D1D),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFF78350F),
    info: Color(0xFF3B82F6),
    infoContainer: Color(0xFF1E3A5F),
    // Inputs
    inputBackground: Color(0xFF2A2A2A),
    inputBorder: Color(0xFF3A3A3A),
    inputFocusedBorder: Color(0xFF64B5F6),
    disabled: Color(0xFF3A3A3A),
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
    );
  }

  @override
  ThemeExtension<DesignTokens> lerp(
    covariant ThemeExtension<DesignTokens>? other,
    double t,
  ) {
    if (other is! DesignTokens) return this;
    return DesignTokens(
      spacingXS: spacingXS,
      spacingS: spacingS,
      spacingM: spacingM,
      spacingL: spacingL,
      spacingXL: spacingXL,
      shapeXS: shapeXS,
      shapeS: shapeS,
      shapeM: shapeM,
      shapeL: shapeL,
      shapeXL: shapeXL,
      shapeFull: shapeFull,
      elevationLevel0: elevationLevel0,
      elevationLevel1: elevationLevel1,
      elevationLevel2: elevationLevel2,
      elevationLevel3: elevationLevel3,
      elevationLevel4: elevationLevel4,
      elevationLevel5: elevationLevel5,
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
