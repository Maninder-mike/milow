import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/theme_provider.dart';

class PrimarySidebar extends ConsumerWidget {
  final VoidCallback onAddRecordTap;
  final VoidCallback onDriversTap;
  final VoidCallback onInboxTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onDashboardTap;
  final String? activePane; // 'add_records' or 'drivers'

  const PrimarySidebar({
    super.key,
    required this.onAddRecordTap,
    required this.onDriversTap,
    required this.onInboxTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    required this.onDashboardTap,
    this.activePane,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 48,
      color: const Color(0xFF202020), // Slightly darker for depth
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Dashboard / Home
          _buildIcon(
            FluentIcons.view_dashboard,
            onTap: onDashboardTap,
            tooltip: 'Dashboard',
            isActive:
                activePane ==
                null, // activePane is null on dashboard main view (usually)
            // Actually DashboardShell logic needs review for active state.
            // activePane is sidebar pane ('add_records', 'drivers').
            // Navigation to /dashboard is independent of pane?
            // Let's assume we highlight Home if not in a specific pane and route is /dashboard.
            // But activePane is passed from parent. Parent needs to handle this logic.
            // For now, let's just add the callback and icon.
            iconSize: 24,
          ),
          const SizedBox(height: 16),
          _buildIcon(
            FluentIcons.add,
            onTap: onAddRecordTap,
            tooltip: 'Add New',
            isActive: activePane == 'add_records',
            iconSize: 24,
          ),
          const SizedBox(height: 16),
          _buildIcon(
            FluentIcons.contact_list, // Changed to ContactList for Drivers
            onTap: onDriversTap,
            tooltip: 'Drivers Directory',
            isActive: activePane == 'drivers',
            iconSize: 24,
          ),
          const SizedBox(height: 16),
          _buildIcon(
            FluentIcons.mail,
            onTap: onInboxTap,
            tooltip: 'Inbox',
            isActive: false, // Inbox is a route, not a pane?
            iconSize: 24,
          ),
          const Spacer(),

          const SizedBox(height: 10),
          _buildSettingsIcon(context, ref),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
  // ... rest remains same including _buildSettingsIcon and _buildIcon

  Widget _buildSettingsIcon(BuildContext context, WidgetRef ref) {
    final controller = FlyoutController();

    return FlyoutTarget(
      controller: controller,
      child: _buildIcon(
        FluentIcons.settings,
        onTap: () {
          controller.showFlyout(
            autoModeConfiguration: FlyoutAutoConfiguration(
              preferredMode: FlyoutPlacementMode.topRight,
            ),
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            dismissWithEsc: true,
            builder: (context) {
              return MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    text: const Text('My Profile'),
                    leading: const Icon(FluentIcons.contact),
                    onPressed: onProfileTap,
                  ),
                  MenuFlyoutSubItem(
                    text: const Text('Themes'),
                    leading: const Icon(FluentIcons.color),
                    items: (context) {
                      return [
                        MenuFlyoutItem(
                          text: const Text('System Default'),
                          onPressed: () {
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(ThemeMode.system);
                          },
                        ),
                        MenuFlyoutItem(
                          text: const Text('Light'),
                          onPressed: () {
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(ThemeMode.light);
                          },
                        ),
                        MenuFlyoutItem(
                          text: const Text('Dark'),
                          onPressed: () {
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(ThemeMode.dark);
                          },
                        ),
                      ];
                    },
                  ),
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    text: const Text('Settings Sync is On'),
                    leading: const Icon(FluentIcons.check_mark),
                    onPressed: () {},
                  ),
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    text: const Text('Check for Updates...'),
                    leading: const Icon(FluentIcons.sync),
                    onPressed: () {},
                  ),
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    text: Text('Sign Out', style: TextStyle(color: Colors.red)),
                    leading: Icon(FluentIcons.sign_out, color: Colors.red),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
        tooltip: 'Settings',
      ),
    );
  }

  Widget _buildIcon(
    IconData icon, {
    required VoidCallback onTap,
    required String tooltip,
    bool isActive = false,
    double iconSize = 24,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: isActive
                  ? const Border(
                      left: BorderSide(color: Colors.white, width: 2),
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: isActive ? Colors.white : const Color(0xFF858585),
            ),
          ),
        ),
      ),
    );
  }
}
