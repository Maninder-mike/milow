import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart'; // Core models

class VehicleRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getVehicles() async {
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

    // Fetch vehicles
    // Ideally we should have a Vehicle model in milow_core.
    // For now returning List<Map> is sufficient for a dropdown.
    final response = await _client
        .from('vehicles')
        .select('id, truck_number, vehicle_type')
        .order('truck_number', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}
