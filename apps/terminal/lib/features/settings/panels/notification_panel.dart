import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/user_preferences_provider.dart';

class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Text(
          'Manage how you receive alerts and updates.',
          style: GoogleFonts.outfit(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 24),

        _buildSettingsCard(
          context,
          children: [
            _buildRow(
              context,
              'Push Notifications',
              'Receive alerts on your desktop.',
              ToggleSwitch(
                checked: prefs.pushNotifications,
                onChanged: (v) {
                  ref
                      .read(userPreferencesProvider.notifier)
                      .setPushNotifications(v);
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            _buildRow(
              context,
              'Email Alerts',
              'Receive critical updates via email.',
              ToggleSwitch(
                checked: prefs.emailAlerts,
                onChanged: (v) {
                  ref.read(userPreferencesProvider.notifier).setEmailAlerts(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String subLabel,
    Widget control,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: FluentTheme.of(context).resources.textFillColorPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subLabel,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
        control,
      ],
    );
  }
}
