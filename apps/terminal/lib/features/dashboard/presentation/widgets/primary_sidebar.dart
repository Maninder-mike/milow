import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class PrimarySidebar extends ConsumerWidget {
  final VoidCallback onAddRecordTap;
  final VoidCallback onDriversTap;
  final VoidCallback onFleetTap;
  final VoidCallback onLoadsTap;
  final VoidCallback onInvoicesTap;
  final VoidCallback onCrmTap;
  final VoidCallback onSettlementsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onDashboardTap;
  final String? activePane; // 'add_record', 'drivers', etc

  const PrimarySidebar({
    super.key,
    required this.onAddRecordTap,
    required this.onDriversTap,
    required this.onFleetTap,
    required this.onLoadsTap,
    required this.onInvoicesTap,
    required this.onCrmTap,
    required this.onSettlementsTap,
    required this.onSettingsTap,
    required this.onProfileTap,
    required this.onDashboardTap,
    this.activePane,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Use Fluent resources for sidebar background
    final backgroundColor = isLight
        ? theme.resources.solidBackgroundFillColorSecondary
        : theme.resources.solidBackgroundFillColorBase;

    return Acrylic(
      tint: backgroundColor,
      tintAlpha: isLight ? 0.98 : 0.8,
      luminosityAlpha: isLight ? 0.99 : 0.9,
      child: SizedBox(
        width: 72, // Wider to fit text
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Dashboard / Home
            _buildNavItem(
              context,
              FluentIcons.home_24_regular,
              label: 'Dashboard',
              onTap: onDashboardTap,
              isActive: activePane == null, // Assuming null is dashboard
            ),
            const SizedBox(height: 16),

            // Add Record (was Fleet)
            _buildNavItem(
              context,
              FluentIcons.add_square_24_regular,
              label: 'Add Record',
              onTap: onAddRecordTap,
              isActive:
                  activePane == 'add_record', // aligned with activePane usage
            ),
            const SizedBox(height: 16),

            // Loads (Recovered Dispatch)
            _buildNavItem(
              context,
              FluentIcons.document_text_24_regular,
              label: 'Loads',
              onTap: onLoadsTap,
              isActive: activePane == 'loads', // or route check
            ),
            const SizedBox(height: 16),

            // Invoices
            _buildNavItem(
              context,
              FluentIcons.money_24_regular,
              label: 'Invoices',
              onTap: onInvoicesTap,
              isActive: activePane == 'invoices',
            ),
            const SizedBox(height: 16),

            // CRM / Directory
            _buildNavItem(
              context,
              FluentIcons.person_note_24_regular,
              label: 'CRM',
              onTap: onCrmTap,
              isActive: activePane == 'crm',
            ),
            const SizedBox(height: 16),

            // Settlements
            _buildNavItem(
              context,
              FluentIcons.receipt_money_24_regular,
              label: 'Settlements',
              onTap: onSettlementsTap,
              isActive: activePane == 'settlements',
            ),
            const SizedBox(height: 16),

            // Drivers
            _buildNavItem(
              context,
              FluentIcons.people_team_24_regular,
              label: 'Drivers',
              onTap: onDriversTap,
              isActive: activePane == 'drivers',
            ),
            const SizedBox(height: 16),

            // Fleet
            _buildNavItem(
              context,
              FluentIcons.vehicle_truck_24_regular,
              label: 'Fleet',
              onTap: onFleetTap,
              isActive:
                  activePane == 'fleet', // Assuming logic for highlighting
            ),

            const Spacer(),

            _buildSettingsIcon(context, ref),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsIcon(BuildContext context, WidgetRef ref) {
    return _buildNavItem(
      context,
      FluentIcons.settings_24_regular,
      label: 'Settings',
      onTap: onSettingsTap,
      isActive: activePane == 'settings',
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon, {
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Active styling
    final activeBgColor = isLight
        ? theme.resources.subtleFillColorSecondary
        : theme.resources.subtleFillColorTertiary;
    final iconColor = isActive
        ? theme.accentColor
        : theme.resources.textFillColorSecondary;

    // Active/Selected indicator line
    final showIndicator = isActive;

    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                width: 64, // Slightly less than container width for padding
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive ? activeBgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 24, color: iconColor),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: iconColor,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showIndicator)
                Positioned(
                  left: 0,
                  top: 16,
                  bottom: 16,
                  width: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
