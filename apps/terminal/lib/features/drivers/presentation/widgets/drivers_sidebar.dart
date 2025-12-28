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
        ? const Color(0xFFE5E5E5) // Slightly darker for contrast
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
                // Filter drivers
                final allDrivers = users
                    .where((u) => u.role == UserRole.driver)
                    .toList();
                final activeDrivers = allDrivers
                    .where((u) => u.isVerified)
                    .toList();
                final inactiveDrivers = allDrivers
                    .where((u) => !u.isVerified)
                    .toList();

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildCollapsibleSection(
                      'ACTIVE DRIVERS',
                      isLight,
                      activeDrivers
                          .map(
                            (driver) =>
                                _buildUserItem(driver, isLight, selectedDriver),
                          )
                          .toList(),
                    ),
                    _buildCollapsibleSection('ON RESET', isLight, []),
                    _buildCollapsibleSection('OFF DUTY', isLight, []),
                    _buildCollapsibleSection(
                      'INACTIVE',
                      isLight,
                      inactiveDrivers
                          .map(
                            (driver) =>
                                _buildUserItem(driver, isLight, selectedDriver),
                          )
                          .toList(),
                    ),
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
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF37373D);

    final isSelected = selectedDriver?.id == driver.id;

    // TODO: Replace mock data with dynamic driver data from backend
    // - tripNumber: from active trip assignment
    // - currentTrip: pickup/delivery locations from trip
    // - statusColor: based on driver's current duty status
    final tripNumber = 'T-1042';
    final currentTrip = 'Chicago, IL → Detroit, MI';
    final statusColor = Colors.green; // Active status

    return HoverButton(
      onPressed: () {
        ref.read(selectedDriverProvider.notifier).select(driver);
        context.go('/drivers');
      },
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor
                : (states.isHovered ? hoverColor : Colors.transparent),
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? FluentTheme.of(context).accentColor
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  _buildAvatar(driver),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLight
                              ? Colors.white
                              : const Color(0xFF252526),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Text(
                      driver.fullName ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Trip info row
                    Row(
                      children: [
                        // Trip number badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? const Color(0xFFE0E0E0)
                                : const Color(0xFF4D4D4D),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            tripNumber,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            currentTrip,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: subTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Assign button on hover
              if (states.isHovered)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'Assign Trip/Truck',
                    child: IconButton(
                      icon: Icon(
                        FluentIcons.add,
                        size: 18,
                        color: FluentTheme.of(context).accentColor,
                      ),
                      onPressed: () {
                        // TODO: Implement assignment dialog
                        _showAssignDialog(context, driver);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, UserProfile driver) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Assign to ${driver.fullName ?? 'Driver'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select what to assign:'),
            const SizedBox(height: 16),
            // TODO: Replace with actual trip/truck selection
            ListTile(
              leading: Icon(FluentIcons.open_folder_horizontal),
              title: const Text('Assign Trip'),
              subtitle: const Text('Select an available trip'),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Show trip selection
              },
            ),
            ListTile(
              leading: Icon(FluentIcons.car),
              title: const Text('Assign Truck'),
              subtitle: const Text('Select an available truck'),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Show truck selection
              },
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
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
