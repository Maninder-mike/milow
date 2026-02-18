import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

/// Repository for fetching vehicle data from Supabase.
class VehicleRepository {
  /// Get the Supabase client to use.
  ///
  /// Defaults to [Supabase.instance.client] but can be overridden.
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  /// Fetches all vehicles for the current user's company.
  ///
  /// Returns an empty list if no company is associated or no vehicles exist.
  static Future<List<Vehicle>> getVehicles({
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final auth = client.auth;
    final session = auth.currentSession;
    final user = auth.currentUser;

    if (user == null) return [];

    final companyId = session?.user.appMetadata['company_id'];

    // Safety check - simpler queries might not fail but good to handle
    if (companyId == null) {
      // Try fetching from profile if claim missing (fallback)
      final profile = await client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) return [];
    }

    final response = await client
        .from('vehicles')
        .select('id, truck_number, vehicle_type')
        .order('truck_number', ascending: true);

    return (response as List)
        .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
