import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class SecondarySidebar extends StatelessWidget {
  final Function(String) onItemTap;

  const SecondarySidebar({super.key, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final backgroundColor = isLight
        ? const Color(0xFFF3F3F3)
        : const Color(0xFF252526);
    // textColor unused here, removed.
    final titleColor = isLight
        ? const Color(0xFF616161)
        : const Color(0xFFBBBBBB);

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            height: 35,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ADD RECORDS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Icon(FluentIcons.more, size: 16, color: titleColor),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem('CUSTOMER', FluentIcons.chevron_right, isLight),
                _buildMenuItem('PICK UP', FluentIcons.chevron_right, isLight),
                _buildMenuItem('DELIVER', FluentIcons.chevron_right, isLight),
                _buildMenuItem('TRUCKS', FluentIcons.chevron_right, isLight),
                _buildMenuItem('TRAILERS', FluentIcons.chevron_right, isLight),
                _buildMenuItem(
                  'HIGHWAY DISPATCH',
                  FluentIcons.chevron_right,
                  isLight,
                ),
                _buildMenuItem(
                  'DRIVER HOS',
                  FluentIcons.chevron_right,
                  isLight,
                ),
                _buildMenuItem('LOCATION', FluentIcons.chevron_right, isLight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, bool isLight) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    return HoverButton(
      onPressed: () => onItemTap(title),
      builder: (context, states) {
        final isHovering = states.isHovered;
        return Container(
          height: 28, // VS Code list item height is usually small
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: isHovering ? hoverColor : Colors.transparent,
          child: Row(
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 6),
              Icon(
                FluentIcons.folder, // Folder icon for categories
                size: 14,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
