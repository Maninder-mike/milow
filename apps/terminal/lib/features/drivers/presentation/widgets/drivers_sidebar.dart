import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../users/data/user_repository_provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/driver_selection_provider.dart';

class DriversSidebar extends ConsumerStatefulWidget {
  const DriversSidebar({super.key});

  @override
  ConsumerState<DriversSidebar> createState() => _DriversSidebarState();
}

class _DriversSidebarState extends ConsumerState<DriversSidebar> {
  final Map<String, bool> _expandedSections = {
    'ACTIVE DRIVERS': true,
    'ON RESET': false,
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

    final usersAsync = ref.watch(usersProvider);
    final selectedDriver = ref.watch(selectedDriverProvider);

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
              onChanged: (value) {
                // TODO: Implement search
              },
            ),
          ),

          // Lists
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Filter verified drivers
                final drivers = users
                    .where((u) => u.role == UserRole.driver && u.isVerified)
                    .toList();

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildCollapsibleSection(
                      'ACTIVE DRIVERS',
                      isLight,
                      drivers
                          .map(
                            (driver) =>
                                _buildUserItem(driver, isLight, selectedDriver),
                          )
                          .toList(),
                    ),
                    _buildCollapsibleSection('ON RESET', isLight, []),
                    _buildCollapsibleSection('OFF DUTY', isLight, []),
                    _buildCollapsibleSection('INACTIVE', isLight, []),
                  ],
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, s) => Center(child: Text('Error: $e')),
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
    // Removed empty check to always show sections

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
              decoration: BoxDecoration(
                color: states.isHovered
                    ? hoverColor
                    : (isLight
                          ? const Color(0xFFFAFAFA)
                          : const Color(
                              0xFF252526,
                            )), // Subtle bg or transparent
                border: Border(
                  top: BorderSide(
                    color: isLight
                        ? const Color(0xFFE5E5E5)
                        : const Color(
                            0xFF3E3E42,
                          ), // VS Code sidebar toggle border color
                    width: 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 4,
                right: 8,
                top: 4,
                bottom: 4,
              ), // increased padding slightly for touch/click
              height: 28, // slight height increase for header
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
                  // Badge count
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

  Widget _buildUserItem(
    UserProfile driver,
    bool isLight,
    UserProfile? selectedDriver,
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
    final selectedColor = isLight
        ? const Color(0xFFE8E8E8) // Visual Studio Code selection style
        : const Color(0xFF37373D);

    final isSelected = selectedDriver?.id == driver.id;

    // Build details string
    String details = driver.email ?? 'No email';
    // If we had trip info, we'd use it here. For now, use role or email.
    if (driver.role.label.isNotEmpty) {
      details = '${driver.role.label} • $details';
    }

    return HoverButton(
      onPressed: () {
        ref.read(selectedDriverProvider.notifier).select(driver);
        context.go('/drivers');
      },
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isSelected
              ? selectedColor
              : (states.isHovered ? hoverColor : Colors.transparent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              _buildAvatar(driver),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          driver.fullName ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (states.isHovered)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.settings,
                                size: 12,
                                color: subTextColor,
                              ),
                              onPressed: () {
                                ref
                                    .read(selectedDriverProvider.notifier)
                                    .select(driver);
                                context.go('/drivers');
                              },
                            ),
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

  Widget _buildAvatar(UserProfile driver) {
    if (driver.avatarUrl != null && driver.avatarUrl!.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          driver.avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialsAvatar(driver),
        ),
      );
    }
    return _buildInitialsAvatar(driver);
  }

  Widget _buildInitialsAvatar(UserProfile driver) {
    String initials = '?';
    if (driver.fullName != null && driver.fullName!.isNotEmpty) {
      final parts = driver.fullName!.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    } else if (driver.email != null && driver.email!.isNotEmpty) {
      initials = driver.email![0].toUpperCase();
    }

    final theme = FluentTheme.of(context);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
