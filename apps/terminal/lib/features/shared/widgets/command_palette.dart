import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Linear/Raycast-style Command Palette (`Cmd+K` / `Ctrl+K`) for enterprise navigation.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const CommandPalette(),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  final List<_CommandItem> _allCommands = [
    _CommandItem(
      category: 'Dispatch',
      title: 'Active Loads Overview',
      subtitle: 'Track active, pending, and completed dispatches',
      icon: FluentIcons.vehicle_truck_profile_24_regular,
      route: '/dispatch',
    ),
    _CommandItem(
      category: 'Dispatch',
      title: 'Live Fleet Map',
      subtitle: 'View real-time driver locations on interactive map',
      icon: FluentIcons.location_24_regular,
      route: '/fleet-map',
    ),
    _CommandItem(
      category: 'Fleet',
      title: 'Vehicles & Trucks',
      subtitle: 'Manage semi-trucks, trailers, and maintenance logs',
      icon: FluentIcons.vehicle_truck_24_regular,
      route: '/vehicles',
    ),
    _CommandItem(
      category: 'Fleet',
      title: 'DVIR Inspection Reports',
      subtitle: 'Review driver pre-trip and post-trip inspections',
      icon: FluentIcons.clipboard_task_24_regular,
      route: '/maintenance',
    ),
    _CommandItem(
      category: 'Billing',
      title: 'Invoices & Billing',
      subtitle: 'Generate customer invoices and track payments',
      icon: FluentIcons.receipt_24_regular,
      route: '/invoices',
    ),
    _CommandItem(
      category: 'Billing',
      title: 'Driver Settlements',
      subtitle: 'Calculate driver pay, fuel deductions, and rates',
      icon: FluentIcons.money_24_regular,
      route: '/settlements',
    ),
    _CommandItem(
      category: 'Analytics',
      title: 'Performance Analytics',
      subtitle: 'Inspect lane metrics, driver efficiency, and revenue',
      icon: FluentIcons.data_trending_24_regular,
      route: '/analytics',
    ),
    _CommandItem(
      category: 'System',
      title: 'Users & Permissions',
      subtitle: 'Manage admin roles, access rights, and drivers',
      icon: FluentIcons.people_24_regular,
      route: '/users',
    ),
    _CommandItem(
      category: 'System',
      title: 'Terminal Settings',
      subtitle: 'Enterprise settings, notifications, and updates',
      icon: FluentIcons.settings_24_regular,
      route: '/settings',
    ),
  ];

  List<_CommandItem> get _filteredCommands {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _allCommands;
    return _allCommands.where((cmd) {
      return cmd.title.toLowerCase().contains(query) ||
          cmd.subtitle.toLowerCase().contains(query) ||
          cmd.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final filtered = _filteredCommands;
      if (filtered.isEmpty) return;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % filtered.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + filtered.length) % filtered.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _executeCommand(filtered[_selectedIndex]);
      }
    }
  }

  void _executeCommand(_CommandItem item) {
    Navigator.of(context).pop();
    context.go(item.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final filtered = _filteredCommands;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _onKey,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 480),
        style: ContentDialogThemeData(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: theme.resources.solidBackgroundFillColorBase,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x42000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
        ),
        content: Column(
          children: [
            // Search Bar Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextBox(
                controller: _searchController,
                focusNode: _focusNode,
                placeholder: 'Type a command or search feature... (⌘K / Ctrl+K)',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(FluentIcons.search_24_regular, size: 18),
                ),
                suffix: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: theme.resources.subtleFillColorSecondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ESC to close',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
            ),
            const Divider(),

            // Command Results List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching commands found',
                        style: TextStyle(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = index == _selectedIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.accentColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            leading: Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? theme.accentColor
                                  : theme.resources.textFillColorPrimary,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: theme.resources.textFillColorPrimary,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.resources.subtleFillColorSecondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            onPressed: () => _executeCommand(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandItem {
  const _CommandItem({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
