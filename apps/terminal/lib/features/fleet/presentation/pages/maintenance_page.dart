import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:terminal/core/widgets/entrance_fader.dart';
import 'package:terminal/features/fleet/data/repositories/maintenance_repository.dart';
import 'package:terminal/features/fleet/presentation/widgets/add_maintenance_dialog.dart';
import 'package:terminal/core/widgets/ui_hardening.dart';
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
            loading: () => const MaintenanceAlertsSkeleton(),
            error: (e, s) => StandardErrorState(
              message: 'Failed to load maintenance alerts: $e',
              onRetry: () => ref.invalidate(fleetMaintenanceAlertsProvider),
            ),
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
        const StandardEmptyState(
          icon: FluentIcons.vehicle_truck_profile_24_regular,
          title: 'Vehicle Specific Schedules',
          message:
              'Select a vehicle from the Fleet sidebar to manage specific maintenance schedules and history.',
        ),
      ],
    );
  }

  Widget _buildEmptyAlertsState(FluentThemeData theme) {
    return const StandardEmptyState(
      icon: FluentIcons.checkmark_circle_24_regular,
      title: 'All Fleet Vehicles Up To Date',
      message: 'No critical maintenance alerts at this time.',
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

class MaintenanceAlertsSkeleton extends StatelessWidget {
  const MaintenanceAlertsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(width: 180, height: 24),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => const SkeletonBox(width: 280, height: 160),
          ),
        ),
      ],
    );
  }
}
