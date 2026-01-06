import 'package:fluent_ui/fluent_ui.dart';

/// Fluent 2 Elevation shadows.
/// Based on: https://fluent2.microsoft.design/elevation
class AppElevation {
  static List<BoxShadow> shadow2(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    return [
      BoxShadow(
        offset: const Offset(0, 0),
        blurRadius: 2,
        color: color.withValues(alpha: 0.12), // Ambient
      ),
      BoxShadow(
        offset: const Offset(0, 1),
        blurRadius: 2,
        color: color, // Spotlight
      ),
    ];
  }

  static List<BoxShadow> shadow4(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    return [
      BoxShadow(
        offset: const Offset(0, 0),
        blurRadius: 2,
        color: color.withValues(alpha: 0.12),
      ),
      BoxShadow(offset: const Offset(0, 2), blurRadius: 4, color: color),
    ];
  }

  static List<BoxShadow> shadow8(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    return [
      BoxShadow(
        offset: const Offset(0, 0),
        blurRadius: 2,
        color: color.withValues(alpha: 0.12),
      ),
      BoxShadow(offset: const Offset(0, 4), blurRadius: 8, color: color),
    ];
  }

  static List<BoxShadow> shadow16(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    return [
      BoxShadow(
        offset: const Offset(0, 0),
        blurRadius: 2,
        color: color.withValues(alpha: 0.12),
      ),
      BoxShadow(offset: const Offset(0, 8), blurRadius: 16, color: color),
    ];
  }

  static List<BoxShadow> shadow64(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.14);

    return [
      BoxShadow(
        offset: const Offset(0, 0),
        blurRadius: 2,
        color: color.withValues(alpha: 0.12),
      ),
      BoxShadow(offset: const Offset(0, 32), blurRadius: 64, color: color),
    ];
  }
}
