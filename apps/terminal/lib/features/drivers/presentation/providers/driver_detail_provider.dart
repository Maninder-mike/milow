import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

part 'driver_detail_provider.g.dart';

class DriverDetailState {
  final Map<String, dynamic>? assignedVehicle;
  final List<dynamic> recentTrips;
  final int totalTrips;
  final double totalMiles;

  DriverDetailState({
    this.assignedVehicle,
    required this.recentTrips,
    required this.totalTrips,
    required this.totalMiles,
  });
}

@riverpod
Future<DriverDetailState> driverDetail(Ref ref, String driverId) async {
  final supabase = Supabase.instance.client;

  // 1. Fetch Assigned Vehicle
  // We can try to parallelize this, but let's define the futures first.
  final vehicleFuture = _fetchAssignedVehicle(supabase, driverId);

  // 2. Fetch Trips (for both recent activity and stats)
  // We fetch all trips or limit?
  // For "Recent Activity" we need top 5.
  // For "Stats" (Total Miles/Trips) we theoretically need aggregate.
  // Ideally, we run a count/sum query for stats, and a select query for recent.
  // But if the dataset is small, fetching all is fine.
  // Let's assume we want to be scalable: separate queries.

  final recentTripsFuture = supabase
      .from('trips')
      .select()
      .eq('user_id', driverId)
      .order('trip_date', ascending: false)
      .limit(5);

  // For stats, we can use a .count() and .sum() if Supabase supports it cleanly,
  // or just fetch lightweight objects.
  // We calculate distance from odometer readings as total_distance column is missing.
  final statsFuture = supabase
      .from('trips')
      .select('start_odometer, end_odometer, distance_unit')
      .eq('user_id', driverId);

  final [vehicle, recentTripsData, statsData] = await Future.wait<dynamic>([
    vehicleFuture,
    recentTripsFuture,
    statsFuture,
  ]);

  final recentTrips = recentTripsData as List<dynamic>;
  final stats = statsData as List<dynamic>;

  double totalMiles = 0;
  for (var trip in stats) {
    final start = (trip['start_odometer'] as num?)?.toDouble() ?? 0;
    final end = (trip['end_odometer'] as num?)?.toDouble() ?? 0;
    final unit = trip['distance_unit'] as String? ?? 'mi';

    double distance = (end - start).abs();
    if (unit.toLowerCase() == 'km') {
      distance *= 0.621371; // Convert to miles
    }
    totalMiles += distance;
  }

  return DriverDetailState(
    assignedVehicle: vehicle as Map<String, dynamic>?,
    recentTrips: recentTrips,
    totalTrips: stats.length,
    totalMiles: totalMiles,
  );
}

Future<Map<String, dynamic>?> _fetchAssignedVehicle(
  SupabaseClient supabase,
  String driverId,
) async {
  try {
    final assignment = await supabase
        .from('fleet_assignments')
        .select('resource_id')
        .eq('assignee_id', driverId)
        .eq('type', 'driver_to_vehicle')
        .isFilter('unassigned_at', null)
        .maybeSingle();

    if (assignment == null) return null;

    final vehicleId = assignment['resource_id'] as String?;
    if (vehicleId == null) return null;

    final vehicle = await supabase
        .from('vehicles')
        .select('truck_number, vehicle_type')
        .eq('id', vehicleId)
        .maybeSingle();

    return vehicle;
  } catch (e) {
    AppLogger.error('Error fetching assigned vehicle: $e');
    return null;
  }
}
