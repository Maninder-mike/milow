import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_elevation.dart';
import '../../../../core/constants/app_colors.dart';

class SecondarySidebar extends StatefulWidget {
  final Function(String) onItemTap;

  const SecondarySidebar({super.key, required this.onItemTap});

  @override
  State<SecondarySidebar> createState() => _SecondarySidebarState();
}

class _SecondarySidebarState extends State<SecondarySidebar> {
  String? _hoveredItem;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final backgroundColor = isLight
        ? theme.resources.solidBackgroundFillColorSecondary
        : theme.resources.solidBackgroundFillColorTertiary;
    final titleColor = theme.resources.textFillColorSecondary;

    return Acrylic(
      tint: backgroundColor,
      tintAlpha: isLight ? 0.95 : 0.75,
      luminosityAlpha: isLight ? 0.98 : 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Quick Actions',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    FluentIcons.more_horizontal_24_regular,
                    size: 16,
                    color: titleColor,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Quick action cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildActionCard(
                  context,
                  isLight,
                  icon: FluentIcons.person_24_regular,
                  title: 'Customer',
                  description: 'Add new customer',
                  color: theme.accentColor,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  isLight,
                  icon: FluentIcons.arrow_upload_24_regular,
                  title: 'Pick Up',
                  description: 'Schedule pickup',
                  color: AppColors.success,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  isLight,
                  icon: FluentIcons.arrow_download_24_regular,
                  title: 'Delivery',
                  description: 'Schedule delivery',
                  color: AppColors.purple,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  isLight,
                  icon: FluentIcons.document_copy_24_regular,
                  title: 'Quotes',
                  description: 'View saved quotes',
                  color: AppColors.info,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  isLight,
                  icon: FluentIcons.money_24_regular,
                  title: 'Invoices',
                  description: 'Manage billing',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    bool isLight, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final theme = FluentTheme.of(context);
    final isHovered = _hoveredItem == title;
    final cardColor = theme.resources.cardBackgroundFillColorDefault;
    final textColor = theme.resources.textFillColorPrimary;
    final subTextColor = theme.resources.textFillColorSecondary;
    final borderColor = isHovered
        ? color.withValues(alpha: 0.5)
        : theme.resources.dividerStrokeColorDefault;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItem = title),
      onExit: (_) => setState(() => _hoveredItem = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onItemTap(title.toUpperCase()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isHovered ? 1.5 : 1),
            boxShadow: isHovered
                ? AppElevation.shadow8(context)
                : AppElevation.shadow2(context),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: isHovered ? color : subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
