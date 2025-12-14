import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/theme_provider.dart';

class PrimarySidebar extends ConsumerWidget {
  final VoidCallback onAddRecordTap;
  final VoidCallback onDriversTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final String? activePane; // 'add_records' or 'drivers'

  const PrimarySidebar({
    super.key,
    required this.onAddRecordTap,
    required this.onDriversTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    this.activePane,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 48,
      color: const Color(0xFF333333),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildIcon(
            FluentIcons.add,
            onTap: onAddRecordTap,
            tooltip: 'Insert Info',
            isActive: activePane == 'add_records',
            iconSize: 24,
          ),
          const SizedBox(height: 10),
          _buildIcon(
            FluentIcons.delivery_truck,
            onTap: onDriversTap,
            tooltip: 'Drivers',
            isActive: activePane == 'drivers',
            iconSize: 20,
          ),
          const Spacer(),

          const SizedBox(height: 10),
          const SizedBox(height: 10),
          _buildSettingsIcon(context, ref),
          const SizedBox(height: 10),
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
