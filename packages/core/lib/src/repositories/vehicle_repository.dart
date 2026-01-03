import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

/// Repository for fetching vehicle data from Supabase.
class VehicleRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetches all vehicles for the current user's company.
  ///
  /// Returns an empty list if no company is associated or no vehicles exist.
  static Future<List<Vehicle>> getVehicles() async {
    final companyId =
        _client.auth.currentSession?.user.appMetadata['company_id'];

    // Safety check - simpler queries might not fail but good to handle
    if (companyId == null) {
      // Try fetching from profile if claim missing (fallback)
      final profile = await _client
          .from('profiles')
          .select('company_id')
          .eq('id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (profile == null) return [];
    }

    final response = await _client
        .from('vehicles')
        .select('id, truck_number, vehicle_type')
        .order('truck_number', ascending: true);

    return (response as List)
        .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
