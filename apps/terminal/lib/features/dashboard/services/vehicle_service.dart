import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';

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
}

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService(ref.read(supabaseClientProvider));
});
