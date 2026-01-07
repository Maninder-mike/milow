import 'package:fluent_ui/fluent_ui.dart';

class AppColors {
  // Status Colors (Fluent Standard) - KEEP THESE
  static const Color success = Color(0xFF107C10);
  static const Color error = Color(0xFFE81123);
  static const Color warning = Color(0xFFCA5010);
  static const Color info = Color(0xFF0078D7);
  static const Color neutral = Color(0xFF737373);
  static const Color teal = Color(0xFF008272);
  static const Color purple = Color(0xFF881798);

  // Role Colors - KEEP THESE
  static const Color roleAdmin = error;
  static const Color roleDispatcher = warning;
  static const Color roleSafetyOfficer = purple;
  static const Color roleDriver = success;
  static const Color roleAssistant = info;
  static const Color rolePending = neutral;
  static const Color roleAccountant = teal;

  // ---------------------------------------------------------------------------
  // DEPRECATED: Legacy UI Colors
  // Use FluentTheme.of(context).resources instead for Fluent 2 compliance.
  // ---------------------------------------------------------------------------

  /// @deprecated Use theme.resources.solidBackgroundFillColorSecondary
  static const Color sidebarBackgroundLight = Color(0xFFF3F3F3);

  /// @deprecated Use theme.resources.solidBackgroundFillColorBase
  static const Color sidebarBackgroundDark = Color(0xFF202020);

  /// @deprecated Use theme.resources.solidBackgroundFillColorSecondary
  static const Color sidebarSecondaryBackgroundLight = Color(0xFFF9F9F9);

  /// @deprecated Use theme.resources.dividerStrokeColorDefault
  static const Color borderLight = Color(0xFFE0E0E0);

  /// @deprecated Use theme.resources.dividerStrokeColorDefault
  static const Color borderDark = Color(0xFF3C3C3C);

  /// @deprecated Use theme.resources.textFillColorPrimary
  static const Color textPrimaryLight = Color(0xFF333333);

  /// @deprecated Use theme.resources.textFillColorPrimary
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  /// @deprecated Use theme.resources.textFillColorSecondary
  static const Color textSecondaryLight = Color(0xFF666666);

  /// @deprecated Use theme.resources.textFillColorSecondary
  static const Color textSecondaryDark = Color(0xFFCCCCCC);

  /// @deprecated Use theme.resources.dividerStrokeColorDefault
  static const Color dividerLight = Color(0xFFE5E5E5);

  /// @deprecated Use theme.resources.dividerStrokeColorDefault
  static const Color dividerDark = Color(0xFF3E3E42);

  /// @deprecated Use theme.resources.subtleFillColorSecondary
  static const Color hoverBackgroundLight = Color(0xFFE8E8E8);

  /// @deprecated Use theme.resources.subtleFillColorSecondary
  static const Color hoverBackgroundDark = Color(0xFF2A2D2E);

  /// @deprecated Use theme.resources.solidBackgroundFillColorBase
  static const Color inputBackgroundDark = Color(0xFF3C3C3C);

  /// @deprecated Use theme.resources.subtleFillColorTertiary
  static const Color badgeBackgroundDark = Color(0xFF4D4D4D);

  /// @deprecated Use theme.resources.solidBackgroundFillColorBase
  static const Color primarySidebarDark = Color(0xFF2D2D2D);

  /// Keep for branded purple action
  static const Color actionPurple = Color(0xFF5C2D91);

  /// @deprecated Use theme.resources.solidBackgroundFillColorBase
  static const Color vsCodeSidebar = Color(0xFF252526);

  /// @deprecated Use theme.resources.dividerStrokeColorDefault
  static const Color vsCodeBorder = Color(0xFF333333);
}
