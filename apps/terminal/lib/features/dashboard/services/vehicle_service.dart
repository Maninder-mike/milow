import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class VehicleService {
  final SupabaseClient _client;

  VehicleService(this._client);

  /// Deletes a vehicle document from both Storage and the Database.
  Future<void> deleteDocument(String id, String path) async {
    // 1. Delete from Storage
    await _client.storage.from('vehicle_documents').remove([path]);

    // 2. Delete from Database
    await _client.from('vehicle_documents').delete().eq('id', id);
  }

  /// Fetches vehicles from the database.
  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final data = await _client
          .from('vehicles')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Fallback to dummy data if fetch fails (or table doesn't exist yet)
      return getDummyVehicles();
    }
  }

  /// Returns dummy vehicle data for UI testing.
  List<Map<String, dynamic>> getDummyVehicles() {
    return [
      {
        'id': '1',
        'vehicle_number': '101',
        'vehicle_type': 'Truck',
        'license_plate': 'TX-1234',
        'vin_number': '1M8...567',
        'status': 'Active', // Active, Maintenance, Idle, Breakdown
        'fuel_level': 0.75, // 75%
        'def_level': 0.80, // 80%
        'engine_temp': 180, // F
        'oil_pressure': 45, // PSI
        'battery_voltage': 14.2, // V
        'engine_hours': 12500,
        'odometer': 450000,
        'mil_status': false, // No Check Engine Light
      },
      {
        'id': '2',
        'vehicle_number': '102',
        'vehicle_type': 'Truck',
        'license_plate': 'CA-5678',
        'vin_number': '1M8...890',
        'status': 'Maintenance',
        'fuel_level': 0.30,
        'def_level': 0.50,
        'engine_temp': 0,
        'oil_pressure': 0,
        'battery_voltage': 12.0,
        'engine_hours': 11000,
        'odometer': 420000,
        'mil_status': true, // Check Engine Light On
      },
      {
        'id': '3',
        'vehicle_number': '103',
        'vehicle_type': 'Trailer',
        'license_plate': 'NY-9012',
        'vin_number': '5T...345',
        'status': 'Idle',
        'fuel_level': 0.0,
        'def_level': 0.0,
        'mil_status': false,
      },
      {
        'id': '4',
        'vehicle_number': '104',
        'vehicle_type': 'Truck',
        'license_plate': 'FL-3456',
        'vin_number': '1M8...123',
        'status': 'Breakdown',
        'fuel_level': 0.10,
        'def_level': 0.20,
        'mil_status': true,
      },
      {
        'id': '5',
        'vehicle_number': '105',
        'vehicle_type': 'Truck',
        'license_plate': 'WA-7890',
        'vin_number': '1M8...456',
        'status': 'Active',
        'fuel_level': 0.90,
        'def_level': 0.95,
        'mil_status': false,
      },
    ];
  }
}

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService(ref.read(supabaseClientProvider));
});

final vehiclesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.read(vehicleServiceProvider);
  return service.getVehicles();
});
