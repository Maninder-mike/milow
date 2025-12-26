import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/widgets/primary_sidebar.dart';
import 'presentation/widgets/secondary_sidebar.dart';
import '../drivers/presentation/widgets/drivers_sidebar.dart';
import 'presentation/widgets/fleet_sidebar.dart';
import 'presentation/widgets/status_bar.dart';
import 'presentation/widgets/main_content_area.dart';
import 'presentation/providers/tab_manager_provider.dart';

import 'presentation/widgets/custom_title_bar.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  String? _activeSidebarPane; // 'add_records', 'drivers', or null
  double _sidebarWidth = 300;
  bool _isResizing = false;

  @override
  void didUpdateWidget(DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTabWithRoute();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTabWithRoute();
    });
  }
  // ... (syncTabWithRoute, navigateTo similar but with sidebar toggle fix)

  void _syncTabWithRoute() {
    if (!mounted) return;
    final location = GoRouterState.of(context).matchedLocation;

    // Skip tab creation for full pages
    if (_isFullPage(location)) return;

    // ... (rest of syncTabWithRoute implementation)
    // Determine title based on location
    String title = 'Untitled';
    IconData? icon;

    if (location.startsWith('/dashboard')) {
      title = 'Dashboard';
      icon = FluentIcons.home_24_regular;
    } else if (location.startsWith('/inbox')) {
      title = 'Inbox';
      icon = FluentIcons.mail_24_regular;
    } else if (location.startsWith('/users/new')) {
      title = 'Add User';
      icon = FluentIcons.person_add_24_regular;
    } else if (location.startsWith('/users')) {
      title = 'Users';
      icon = FluentIcons.people_24_regular;
    } else if (location.startsWith('/profile')) {
      title = 'My Profile';
      icon = FluentIcons.person_24_regular;
    } else if (location.startsWith('/settings')) {
      title = 'Settings';
      icon = FluentIcons.settings_24_regular;
    } else if (location.startsWith('/customer')) {
      title = 'Customer';
      icon = FluentIcons.person_24_regular;
    } else if (location.startsWith('/pickup')) {
      title = 'Pick Up';
      icon = FluentIcons.box_24_regular;
    } else if (location.startsWith('/deliver')) {
      title = 'Deliver';
      icon = FluentIcons.vehicle_truck_24_regular;
    } else if (location.startsWith('/vehicles')) {
      title = 'Vehicles';
      icon = FluentIcons.vehicle_car_24_regular;
    } else if (location.startsWith('/highway-dispatch')) {
      title = 'Dispatch';
      icon = FluentIcons.layer_24_regular;
    } else if (location.startsWith('/driver-hos')) {
      title = 'Driver HOS';
      icon = FluentIcons.clock_24_regular;
    } else if (location.startsWith('/location')) {
      title = 'Location';
      icon = FluentIcons.location_24_regular;
    } else if (location.startsWith('/drivers')) {
      title = 'Drivers';
      icon = FluentIcons.vehicle_truck_24_regular;
    }

    final tab = TabInfo(
      id: location,
      title: title,
      icon: icon,
      child: widget.child,
      path: location,
    );

    ref.read(tabManagerProvider.notifier).addTab(tab);
  }

  void _toggleSidebar(String pane) {
    setState(() {
      if (_activeSidebarPane == pane) {
        _activeSidebarPane = null; // Close
      } else {
        _activeSidebarPane = pane; // Open/Switch
        if (_sidebarWidth == 0) _sidebarWidth = 300; // Restore width if hidden
      }
    });
  }

  void _navigateTo(String path) {
    if (!mounted) return;
    final currentLocation = GoRouterState.of(context).matchedLocation;

    if (currentLocation == path) {
      _syncTabWithRoute();
    } else {
      context.go(path);
    }
  }

  final _searchFocusNode = FocusNode();

  bool _isFullPage(String location) {
    return location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location.startsWith('/dashboard');
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            CustomTitleBar(searchFocusNode: _searchFocusNode),

            Expanded(
              child: Row(
                children: [
                  PrimarySidebar(
                    onAddRecordTap: () => _toggleSidebar('add_record'),
                    onDriversTap: () => _toggleSidebar('drivers'),
                    onFleetTap: () => _toggleSidebar('fleet_list'),
                    onLoadsTap: () => _navigateTo('/highway-dispatch'),
                    onSettingsTap: () => _navigateTo('/settings'),
                    onProfileTap: () => _navigateTo('/profile'),
                    onDashboardTap: () => _navigateTo('/dashboard'),
                    activePane: _activeSidebarPane,
                  ),

                  // Resizable Sidebar Area
                  if (_activeSidebarPane != null)
                    SizedBox(
                      width: _sidebarWidth,
                      child: _buildSecondarySidebar(_activeSidebarPane!),
                    ),

                  // Drag Handle (Invisible visual, wider hit target)
                  if (_activeSidebarPane != null)
                    SizedBox(
                      width: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -4, // Center tap target
                            top: 0,
                            bottom: 0,
                            width: 9,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    _sidebarWidth =
                                        (_sidebarWidth + details.primaryDelta!)
                                            .clamp(150.0, 600.0);
                                    _isResizing = true;
                                  });
                                },
                                onHorizontalDragEnd: (_) {
                                  setState(() => _isResizing = false);
                                },
                                child: Container(
                                  color: _isResizing
                                      ? FluentTheme.of(
                                          context,
                                        ).cardColor.withValues(alpha: 0.95)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child:
                        _isFullPage(GoRouterState.of(context).matchedLocation)
                        ? widget.child
                        : const MainContentArea(),
                  ),
                ],
              ),
            ),

            const StatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondarySidebar(String pane) {
    switch (pane) {
      case 'add_record':
        return SecondarySidebar(
          onItemTap: (item) {
            switch (item) {
              case 'CUSTOMER':
                _navigateTo('/customer');
                break;
              case 'PICK UP':
                _navigateTo('/pickup');
                break;
              case 'DELIVER':
                _navigateTo('/deliver');
                break;
              case 'HIGHWAY DISPATCH':
                _navigateTo('/highway-dispatch');
                break;
              case 'DRIVER HOS':
                _navigateTo('/driver-hos');
                break;
              case 'LOCATION':
                _navigateTo('/location');
                break;
            }
          },
        );
      case 'drivers':
        return const DriversSidebar();
      case 'fleet_list':
        return const FleetSidebar();
      default:
        return const SizedBox.shrink();
    }
  }
}
