import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class DriversSidebar extends StatefulWidget {
  const DriversSidebar({super.key});

  @override
  State<DriversSidebar> createState() => _DriversSidebarState();
}

class _DriversSidebarState extends State<DriversSidebar> {
  final Map<String, bool> _expandedSections = {
    'ACTIVE DRIVERS': true,
    'ON RESET':
        false, // Default closed like image/request implies specific focus
    'OFF DUTY': false,
    'INACTIVE': false,
  };

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = isLight
        ? const Color(0xFFF3F3F3)
        : const Color(0xFF252526);
    final titleColor = isLight
        ? const Color(0xFF616161)
        : const Color(0xFFBBBBBB);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            height: 35,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DRIVERS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(FluentIcons.more, size: 14, color: titleColor),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextBox(
              placeholder: 'Search Drivers...',
              placeholderStyle: GoogleFonts.inter(
                color: isLight ? Colors.grey[100] : const Color(0xFF858585),
                fontSize: 13,
              ),
              style: GoogleFonts.inter(
                color: isLight ? Colors.black : Colors.white,
                fontSize: 13,
              ),
              decoration: WidgetStateProperty.all(
                BoxDecoration(
                  color: isLight
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF3C3C3C),
                  border: Border.all(
                    color: isLight
                        ? const Color(0xFFE0E0E0)
                        : const Color(0xFF3C3C3C),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cursorColor: isLight ? Colors.black : Colors.white,
            ),
          ),

          // Lists
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCollapsibleSection('ACTIVE DRIVERS', isLight, [
                  _buildDriverItem(
                    'Mike Ross',
                    'Trip #1024 - Delivering',
                    'MR',
                    Colors.blue,
                    isLight,
                  ),
                  _buildDriverItem(
                    'Harvey Specter',
                    'Trip #1025 - Pickup',
                    'HS',
                    Colors.purple,
                    isLight,
                  ),
                ]),
                const Divider(),
                _buildCollapsibleSection('ON RESET', isLight, [
                  _buildDriverItem(
                    'Louis Litt',
                    'Resetting at Yard',
                    'LL',
                    Colors.orange,
                    isLight,
                  ),
                ]),
                const Divider(),
                _buildCollapsibleSection('OFF DUTY', isLight, [
                  _buildDriverItem(
                    'Rachel Zane',
                    'Home',
                    'RZ',
                    Colors.green,
                    isLight,
                  ),
                ]),
                const Divider(),
                _buildCollapsibleSection('INACTIVE', isLight, [
                  _buildDriverItem(
                    'Donna Paulsen',
                    'On Leave',
                    'DP',
                    Colors.red,
                    isLight,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    bool isLight,
    List<Widget> children,
  ) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    final isExpanded = _expandedSections[title] ?? false;

    return Column(
      children: [
        HoverButton(
          onPressed: () => _toggleSection(title),
          builder: (context, states) {
            return Container(
              color: states.isHovered ? hoverColor : Colors.transparent,
              padding: const EdgeInsets.only(
                left: 4,
                right: 8,
                top: 2,
                bottom: 2,
              ), // Compact like VS Code
              height: 22,
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? FluentIcons.chevron_down
                        : FluentIcons.chevron_right,
                    size: 8,
                    color: textColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  // Badge count (simulated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF4D4D4D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${children.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (isExpanded) Column(children: children),
      ],
    );
  }

  Widget _buildDriverItem(
    String name,
    String details,
    String initials,
    Color color,
    bool isLight,
  ) {
    final textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final subTextColor = isLight
        ? const Color(0xFF666666)
        : const Color(0xFF999999);
    final hoverColor = isLight
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF2A2D2E);

    return HoverButton(
      onPressed: () {},
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: states.isHovered ? hoverColor : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture (Placeholder)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (states.isHovered)
                          Icon(
                            FluentIcons.settings,
                            size: 12,
                            color: subTextColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
