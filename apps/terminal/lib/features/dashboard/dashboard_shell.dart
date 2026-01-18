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
      title = 'Delivery';
      icon = FluentIcons.vehicle_truck_24_regular;
    } else if (location.startsWith('/vehicles')) {
      title = 'Fleet';
      icon = FluentIcons.vehicle_truck_24_regular;
    } else if (location.startsWith('/highway-dispatch')) {
      title = 'Loads';
      icon = FluentIcons.document_text_24_regular;
    } else if (location.startsWith('/quotes')) {
      title = 'Quotes';
      icon = FluentIcons.document_copy_24_regular;
    } else if (location.startsWith('/invoices')) {
      title = 'Invoices';
      icon = FluentIcons.money_24_regular;
    } else if (location.startsWith('/driver-hos')) {
      title = 'Driver HOS';
      icon = FluentIcons.clock_24_regular;
    } else if (location.startsWith('/location')) {
      title = 'Location';
      icon = FluentIcons.location_24_regular;
    } else if (location.startsWith('/drivers')) {
      title = 'Drivers';
      icon = FluentIcons.people_team_24_regular;
    } else if (location.startsWith('/crm')) {
      title = 'CRM / Directory';
      icon = FluentIcons.person_note_24_regular;
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

    setState(() {
      _activeSidebarPane = null; // Close sidebars on main nav
    });

    if (currentLocation == path ||
        (path == '/settings' && currentLocation.startsWith('/settings/')) ||
        (path == '/profile' && currentLocation.startsWith('/profile/'))) {
      if (path == '/settings' || path == '/profile') {
        context.go('/dashboard');
      } else {
        _syncTabWithRoute();
      }
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
    final tabState = ref.watch(tabManagerProvider);
    final tabs = tabState.tabs;
    final selectedIndex = tabState.selectedIndex;

    // Define shortcuts map
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
        _searchFocusNode.requestFocus();
      },
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
        _searchFocusNode.requestFocus();
      },
      const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () {
        if (tabs.isNotEmpty) {
          ref.read(tabManagerProvider.notifier).removeTab(selectedIndex);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        if (tabs.isNotEmpty) {
          ref.read(tabManagerProvider.notifier).removeTab(selectedIndex);
        }
      },
    };

    // Add Cmd+1 to Cmd+9
    final numberKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    for (int i = 0; i < numberKeys.length; i++) {
      shortcuts[SingleActivator(numberKeys[i], meta: true)] = () {
        if (i < tabs.length) {
          _navigateTo(tabs[i].path ?? '/dashboard');
        }
      };
      shortcuts[SingleActivator(numberKeys[i], control: true)] = () {
        if (i < tabs.length) {
          _navigateTo(tabs[i].path ?? '/dashboard');
        }
      };
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            CustomTitleBar(searchFocusNode: _searchFocusNode),

            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      PrimarySidebar(
                        onAddRecordTap: () => _toggleSidebar('add_record'),
                        onDriversTap: () => _toggleSidebar('drivers'),
                        onFleetTap: () => _toggleSidebar('fleet'),
                        onLoadsTap: () => _navigateTo('/highway-dispatch'),
                        onInvoicesTap: () => _navigateTo('/invoices'),
                        onCrmTap: () => _navigateTo('/crm'),
                        onSettlementsTap: () => _navigateTo('/settlements'),
                        onSettingsTap: () => _navigateTo('/settings'),
                        onProfileTap: () => _navigateTo('/profile'),
                        onDashboardTap: () => _navigateTo('/dashboard'),
                        activePane: _activeSidebarPane,
                        currentLocation: GoRouterState.of(
                          context,
                        ).matchedLocation,
                      ),

                      // Resizable Sidebar Area
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        width: _activeSidebarPane != null ? _sidebarWidth : 0,
                        child: ClipRect(
                          child: _activeSidebarPane != null
                              ? _buildSecondarySidebar(_activeSidebarPane!)
                              : const SizedBox.shrink(),
                        ),
                      ),

                      Expanded(
                        child: Mica(
                          child:
                              _isFullPage(
                                GoRouterState.of(context).matchedLocation,
                              )
                              ? widget.child
                              : const MainContentArea(),
                        ),
                      ),
                    ],
                  ),

                  // Overlay Drag Handle (positioned at right edge of sidebar)
                  if (_activeSidebarPane != null)
                    Positioned(
                      left:
                          72 +
                          _sidebarWidth -
                          4, // Primary sidebar width + secondary sidebar width - half handle width
                      top: 0,
                      bottom: 0,
                      width: 8,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _sidebarWidth =
                                  (_sidebarWidth + details.primaryDelta!).clamp(
                                    150.0,
                                    600.0,
                                  );
                            });
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),
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
              case 'DELIVERY':
                _navigateTo('/deliver');
                break;
              case 'HIGHWAY DISPATCH':
                _navigateTo('/highway-dispatch');
                break;
              case 'QUOTES':
                _navigateTo('/quotes');
                break;
              case 'INVOICES':
                _navigateTo('/invoices');
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
      case 'fleet':
        return const FleetSidebar();
      default:
        return const SizedBox.shrink();
    }
  }
}
