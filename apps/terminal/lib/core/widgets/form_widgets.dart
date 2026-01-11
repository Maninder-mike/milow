import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class FluentSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool showDivider;

  const FluentSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    // Simple style (all caps, accent color)
    if (icon == null && !showDivider) {
      return Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: FluentTheme.of(context).accentColor,
        ),
      );
    }

    // Header with Icon and/or Divider
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: FluentTheme.of(context).accentColor),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: FluentTheme.of(context).resources.textFillColorPrimary,
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ],
      ],
    );
  }
}

class FluentLabeledInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final bool enabled;

  const FluentLabeledInput({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isLight ? Colors.grey[140] : Colors.grey[80],
            ),
          ),
        ),
        TextFormBox(
          controller: controller,
          placeholder: placeholder,
          style: const TextStyle(fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          suffix: suffix,
          enabled: enabled,
        ),
      ],
    );
  }
}

class FluentOptionChip extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const FluentOptionChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: value
              ? theme.accentColor
              : (isLight ? const Color(0xFFF0F0F0) : const Color(0xFF2D2D2D)),
          borderRadius: BorderRadius.circular(
            100,
          ), // Pill shape preserved per user request
          border: Border.all(
            color: value
                ? theme.accentColor
                : (isLight ? const Color(0xFFE5E5E5) : const Color(0xFF3D3D3D)),
            width: 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: value
                  ? Colors.white
                  : (isLight ? Colors.grey[140] : Colors.grey[80]),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value
                    ? Colors.white
                    : (isLight
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
