import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminal/features/dashboard/services/admin_dashboard_service.dart';

final adminDashboardServiceProvider = Provider<AdminDashboardService>((ref) {
  return AdminDashboardService();
});
