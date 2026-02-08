import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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
          'Choose how you want to be notified about different activities across the platform.',
          style: GoogleFonts.outfit(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 24),

        _buildCategory(
          context,
          title: 'Operations',
          description: 'Updates on loads, shipments, and driver status.',
          icon: FluentIcons.vehicle_truck_profile_24_regular,
          children: [
            _buildNotificationRow(
              context,
              label: 'Operational Alerts',
              subLabel: 'Status changes, delays, and critical updates.',
              pushValue: prefs.opsPush,
              emailValue: prefs.opsEmail,
              onPushChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setOpsPush(v),
              onEmailChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setOpsEmail(v),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildCategory(
          context,
          title: 'Messages',
          description: 'Communication from your team and drivers.',
          icon: FluentIcons.chat_24_regular,
          children: [
            _buildNotificationRow(
              context,
              label: 'Team Communication',
              subLabel: 'Direct messages and team-wide announcements.',
              pushValue: prefs.msgPush,
              emailValue: prefs.msgEmail,
              onPushChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setMsgPush(v),
              onEmailChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setMsgEmail(v),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildCategory(
          context,
          title: 'Safety & Compliance',
          description: 'Logs, inspections, and safety violations.',
          icon: FluentIcons.shield_24_regular,
          children: [
            _buildNotificationRow(
              context,
              label: 'Compliance Tracking',
              subLabel: 'DVIR alerts, HOS violations, and document renewals.',
              pushValue: prefs.safetyPush,
              emailValue: prefs.safetyEmail,
              onPushChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setSafetyPush(v),
              onEmailChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setSafetyEmail(v),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildCategory(
          context,
          title: 'Account & Security',
          description: 'System updates and sensitive account changes.',
          icon: FluentIcons.settings_24_regular,
          children: [
            _buildNotificationRow(
              context,
              label: 'Security & Billing',
              subLabel: 'Login attempts, billing issues, and account security.',
              pushValue: prefs.accountPush,
              emailValue: prefs.accountEmail,
              onPushChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setAccountPush(v),
              onEmailChanged: (v) =>
                  ref.read(userPreferencesProvider.notifier).setAccountEmail(v),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: FluentTheme.of(context).accentColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FluentTheme.of(
                context,
              ).resources.dividerStrokeColorDefault,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildNotificationRow(
    BuildContext context, {
    required String label,
    required String subLabel,
    required bool pushValue,
    required bool emailValue,
    required ValueChanged<bool> onPushChanged,
    required ValueChanged<bool> onEmailChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: FluentTheme.of(
                      context,
                    ).resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _buildToggleColumn(context, 'Push', pushValue, onPushChanged),
          const SizedBox(width: 16),
          _buildToggleColumn(context, 'Email', emailValue, onEmailChanged),
        ],
      ),
    );
  }

  Widget _buildToggleColumn(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ToggleSwitch(checked: value, onChanged: onChanged),
      ],
    );
  }
}
