import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../dispatch/presentation/providers/load_providers.dart';
import '../../../billing/presentation/providers/invoice_providers.dart';
import '../../services/vehicle_service.dart';

part 'dashboard_metrics_provider.g.dart';

class DashboardMetrics {
  final int activeLoads;
  final int awaitingDispatch;
  final double revenueMTD;
  final double fleetHealthPercent;
  final int criticalAlertsCount;

  DashboardMetrics({
    required this.activeLoads,
    required this.awaitingDispatch,
    required this.revenueMTD,
    required this.fleetHealthPercent,
    required this.criticalAlertsCount,
  });
}

@riverpod
Future<DashboardMetrics> dashboardMetrics(Ref ref) async {
  final loads = await ref.watch(loadsListProvider.future);
  final vehicles = await ref.watch(vehiclesListProvider.future);
  final invoices = await ref.watch(
    invoicesListProvider(statusFilter: null).future,
  );

  // 1. Active Loads (In Transit/Arrived/etc.)
  final activeLoads = loads
      .where(
        (l) =>
            l.status.toUpperCase() != 'AVAILABLE' &&
            l.status.toUpperCase() != 'PENDING' &&
            l.status.toUpperCase() != 'DELIVERED' &&
            l.status.toUpperCase() != 'CANCELLED',
      )
      .length;

  // 2. Awaiting Dispatch (Available/Pending)
  final awaitingDispatch = loads
      .where(
        (l) =>
            l.status.toUpperCase() == 'AVAILABLE' ||
            l.status.toUpperCase() == 'PENDING',
      )
      .length;

  // 3. Revenue MTD
  final now = DateTime.now();
  final firstDayMonth = DateTime(now.year, now.month, 1);
  final revenueMTD = invoices
      .where((inv) => inv.createdAt?.isAfter(firstDayMonth) ?? false)
      .fold<double>(0, (sum, inv) => sum + inv.totalAmount);

  // 4. Fleet Health %
  final totalVehicles = vehicles.length;
  final healthyVehicles = vehicles.where((v) {
    final status = (v['status'] as String?)?.toLowerCase() ?? '';
    return status != 'breakdown' && status != 'maintenance';
  }).length;
  final healthPercent = totalVehicles > 0
      ? (healthyVehicles / totalVehicles) * 100
      : 100.0;

  // 5. Critical Alerts
  final criticalAlerts = vehicles.where((v) => v['mil_status'] == true).length;

  return DashboardMetrics(
    activeLoads: activeLoads,
    awaitingDispatch: awaitingDispatch,
    revenueMTD: revenueMTD,
    fleetHealthPercent: healthPercent.toDouble(),
    criticalAlertsCount: criticalAlerts,
  );
}
