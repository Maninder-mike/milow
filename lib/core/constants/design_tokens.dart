import 'package:flutter/material.dart';

/// DesignTokens encapsulates spacing, radii, elevations and shared colors.
/// Added as a ThemeExtension so we can access via Theme.of(context).extension<DesignTokens>()
class DesignTokens extends ThemeExtension<DesignTokens> {
  final double spacingXS;
  final double spacingS;
  final double spacingM;
  final double spacingL;
  final double spacingXL;

  final double radiusS;
  final double radiusM;
  final double radiusL;

  final double cardElevation;
  final Color subtleBorderColor;
  final Color sectionLabelColor;
  final Color scaffoldAltBackground;

  const DesignTokens({
    required this.spacingXS,
    required this.spacingS,
    required this.spacingM,
    required this.spacingL,
    required this.spacingXL,
    required this.radiusS,
    required this.radiusM,
    required this.radiusL,
    required this.cardElevation,
    required this.subtleBorderColor,
    required this.sectionLabelColor,
    required this.scaffoldAltBackground,
  });

  static const light = DesignTokens(
    spacingXS: 4,
    spacingS: 8,
    spacingM: 16,
    spacingL: 24,
    spacingXL: 32,
    radiusS: 8,
    radiusM: 12,
    radiusL: 16,
    cardElevation: 0,
    subtleBorderColor: Color(0xFFD0D5DD),
    sectionLabelColor: Color(0xFF98A2B3),
    scaffoldAltBackground: Color(0xFFF9FAFB),
  );

  static const dark = DesignTokens(
    spacingXS: 4,
    spacingS: 8,
    spacingM: 16,
    spacingL: 24,
    spacingXL: 32,
    radiusS: 8,
    radiusM: 12,
    radiusL: 16,
    cardElevation: 0,
    subtleBorderColor: Color(0xFF3A3A3A),
    sectionLabelColor: Color(0xFF9CA3AF),
    scaffoldAltBackground: Color(0xFF121212),
  );

  @override
  ThemeExtension<DesignTokens> copyWith({
    double? spacingXS,
    double? spacingS,
    double? spacingM,
    double? spacingL,
    double? spacingXL,
    double? radiusS,
    double? radiusM,
    double? radiusL,
    double? cardElevation,
    Color? subtleBorderColor,
    Color? sectionLabelColor,
    Color? scaffoldAltBackground,
  }) {
    return DesignTokens(
      spacingXS: spacingXS ?? this.spacingXS,
      spacingS: spacingS ?? this.spacingS,
      spacingM: spacingM ?? this.spacingM,
      spacingL: spacingL ?? this.spacingL,
      spacingXL: spacingXL ?? this.spacingXL,
      radiusS: radiusS ?? this.radiusS,
      radiusM: radiusM ?? this.radiusM,
      radiusL: radiusL ?? this.radiusL,
      cardElevation: cardElevation ?? this.cardElevation,
      subtleBorderColor: subtleBorderColor ?? this.subtleBorderColor,
      sectionLabelColor: sectionLabelColor ?? this.sectionLabelColor,
      scaffoldAltBackground:
          scaffoldAltBackground ?? this.scaffoldAltBackground,
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
      radiusS: radiusS,
      radiusM: radiusM,
      radiusL: radiusL,
      cardElevation: cardElevation,
      subtleBorderColor:
          Color.lerp(subtleBorderColor, other.subtleBorderColor, t) ??
          subtleBorderColor,
      sectionLabelColor:
          Color.lerp(sectionLabelColor, other.sectionLabelColor, t) ??
          sectionLabelColor,
      scaffoldAltBackground:
          Color.lerp(scaffoldAltBackground, other.scaffoldAltBackground, t) ??
          scaffoldAltBackground,
    );
  }
}
