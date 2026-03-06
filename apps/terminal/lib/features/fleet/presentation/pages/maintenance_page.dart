import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:terminal/core/widgets/entrance_fader.dart';
import 'package:terminal/features/fleet/data/repositories/maintenance_repository.dart';
import 'package:terminal/features/fleet/presentation/widgets/add_maintenance_dialog.dart';
import 'package:milow_core/milow_core.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  final _searchController = TextEditingController();

  // We'll filter alerts to show all fleet defaults
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Fleet Alerts
    final alertsAsync = ref.watch(fleetMaintenanceAlertsProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Preventive Maintenance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add_24_regular),
              label: const Text('Log Service Record'),
              onPressed: _showAddMaintenanceDialog,
            ),
          ],
        ),
      ),
      children: [
        // Top Section: Critical Overdue Maintenance Alerts
        EntranceFader(
          delay: const Duration(milliseconds: 100),
          child: alertsAsync.when(
            data: (alerts) {
              if (alerts.isEmpty) {
                return _buildEmptyAlertsState(theme);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overdue Service Alerts',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: alerts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _buildAlertCard(alert, theme);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (e, s) => Center(child: Text('Error loading alerts: $e')),
          ),
        ),
        const SizedBox(height: 32),
        // Future section: Full fleet maintenance schedule list (Stubbed for now)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All Schedules',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 300,
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search vehicles...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(FluentIcons.search_24_regular),
                ),
                onChanged: (val) {
                  // Future use
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
              style: BorderStyle.none,
            ),
          ),
          child: Column(
            children: [
              Icon(
                FluentIcons.vehicle_truck_profile_24_regular,
                size: 32,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Select a vehicle from the Fleet sidebar to manage specific maintenance schedules.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAlertsState(FluentThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
          style: BorderStyle.none,
        ),
      ),
      child: Column(
        children: [
          Icon(
            FluentIcons.checkmark_circle_24_regular,
            size: 32,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            'All Fleet Vehicles Up To Date',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.resources.textFillColorPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No maintenance alerts triggered.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    ({MaintenanceSchedule schedule, String vehicleNumber}) alert,
    FluentThemeData theme,
  ) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Vehicle \${alert.vehicleNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const Icon(
                FluentIcons.warning_24_regular,
                color: Color(0xFFF44336),
                size: 16,
              ),
            ],
          ),
          const Spacer(),
          Text(
            alert.schedule.serviceType.displayName,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overdue for service',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Button(
              child: const Text('Resolve'),
              onPressed: () => _resolveAlert(alert),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMaintenanceDialog() {
    // Need a vehicle ID context to add maintenance directly, so we tell user to select one
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Select Vehicle'),
        content: const Text(
          'Please select a specific vehicle from the fleet sidebar to add a service record.',
        ),
        severity: InfoBarSeverity.warning,
        onClose: close,
      ),
    );
  }

  void _resolveAlert(
    ({MaintenanceSchedule schedule, String vehicleNumber}) alert,
  ) {
    showDialog(
      context: context,
      builder: (context) => AddMaintenanceDialog(
        vehicleId: alert.schedule.vehicleId,
        onSaved: () {
          ref.invalidate(fleetMaintenanceAlertsProvider);
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Success'),
              content: const Text('Service record logged and alert resolved.'),
              severity: InfoBarSeverity.success,
              onClose: close,
            ),
          );
        },
      ),
    );
  }
}
