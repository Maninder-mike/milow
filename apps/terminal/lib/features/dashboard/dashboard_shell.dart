import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/widgets/primary_sidebar.dart';
import 'presentation/widgets/secondary_sidebar.dart';
import '../drivers/presentation/widgets/drivers_sidebar.dart';
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
      icon = FluentIcons.home;
    } else if (location.startsWith('/inbox')) {
      title = 'Inbox';
      icon = FluentIcons.mail;
    } else if (location.startsWith('/users/new')) {
      title = 'Add User';
      icon = FluentIcons.add_friend;
    } else if (location.startsWith('/users')) {
      title = 'Users';
      icon = FluentIcons.people;
    } else if (location.startsWith('/profile')) {
      title = 'My Profile';
      icon = FluentIcons.contact;
    } else if (location.startsWith('/settings')) {
      title = 'Settings';
      icon = FluentIcons.settings;
    } else if (location.startsWith('/customer')) {
      title = 'Customer';
      icon = FluentIcons.contact;
    } else if (location.startsWith('/pickup')) {
      title = 'Pick Up';
      icon = FluentIcons.package;
    } else if (location.startsWith('/deliver')) {
      title = 'Deliver';
      icon = FluentIcons.delivery_truck;
    } else if (location.startsWith('/vehicles')) {
      title = 'Vehicles';
      icon = FluentIcons.processing;
    } else if (location.startsWith('/highway-dispatch')) {
      title = 'Dispatch';
      icon = FluentIcons.map_layers;
    } else if (location.startsWith('/driver-hos')) {
      title = 'Driver HOS';
      icon = FluentIcons.clock;
    } else if (location.startsWith('/location')) {
      title = 'Location';
      icon = FluentIcons.location;
    } else if (location.startsWith('/drivers')) {
      title = 'Drivers';
      icon = FluentIcons.delivery_truck;
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
                    onAddRecordTap: () => _toggleSidebar('add_records'),
                    onDriversTap: () => _toggleSidebar('drivers'),
                    onInboxTap: () => _navigateTo('/inbox'),
                    onSettingsTap: () => _navigateTo('/settings'),
                    onProfileTap: () => _navigateTo('/profile'),
                    onDashboardTap: () => _navigateTo('/dashboard'),
                    activePane: _activeSidebarPane,
                  ),

                  // Resizable Sidebar Area
                  if (_activeSidebarPane != null)
                    SizedBox(
                      width: _sidebarWidth,
                      child: _activeSidebarPane == 'add_records'
                          ? SecondarySidebar(
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
                                  case 'VEHICLES':
                                    _navigateTo('/vehicles');
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
                            )
                          : const DriversSidebar(),
                    ),

                  // Drag Handle (1px visual, wider hit target)
                  if (_activeSidebarPane != null)
                    Container(
                      width: 1,
                      color:
                          FluentTheme.of(context).brightness == Brightness.light
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF333333),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -4, // Center 9px tap target over 1px line
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
}
