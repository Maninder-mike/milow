import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Service for managing fuel entries in Supabase
class FuelService {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      client.auth.currentUser?.id;

  /// Create a new fuel entry
  static Future<FuelEntry?> createFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final data = entry.toJson();
      data['user_id'] = userId;
      data.remove('id'); // Let database generate ID

      final response = await client
          .from('fuel_entries')
          .insert(data)
          .select()
          .single();

      return FuelEntry.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all fuel entries for current user
  static Future<List<FuelEntry>> getFuelEntries({
    int? limit,
    DateTime? fromDate,
    DateTime? toDate,
    String? fuelType, // 'truck' or 'reefer'
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      var query = client.from('fuel_entries').select().eq('user_id', userId);

      if (fuelType != null) {
        query = query.eq('fuel_type', fuelType);
      }
      if (fromDate != null) {
        query = query.gte('fuel_date', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('fuel_date', toDate.toIso8601String());
      }

      final response = await query.order('fuel_date', ascending: false);

      List<dynamic> data = response;
      if (limit != null) {
        data = data.take(limit).toList();
      }

      return data.map((json) => FuelEntry.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single fuel entry by ID
  static Future<FuelEntry?> getFuelEntryById(
    String entryId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('fuel_entries')
          .select()
          .eq('id', entryId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return FuelEntry.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing fuel entry
  static Future<FuelEntry?> updateFuelEntry(
    FuelEntry entry, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (entry.id == null) {
      throw Exception('Fuel entry ID is required for update');
    }

    try {
      final data = entry.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await client
          .from('fuel_entries')
          .update(data)
          .eq('id', entry.id!)
          .eq('user_id', userId)
          .select()
          .single();

      return FuelEntry.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a fuel entry
  static Future<void> deleteFuelEntry(
    String entryId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await client
          .from('fuel_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete fuel entry: $e');
    }
  }

  /// Get total fuel entries count for current user
  static Future<int> getFuelEntriesCount({
    String? fuelType,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      var query = client.from('fuel_entries').select().eq('user_id', userId);

      if (fuelType != null) {
        query = query.eq('fuel_type', fuelType);
      }

      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw Exception('Failed to get fuel entries count: $e');
    }
  }

  /// Get total fuel cost for all entries
  static Future<Map<String, double>> getTotalFuelCost({
    SupabaseClient? supabaseClient,
  }) async {
    final entries = await getFuelEntries(supabaseClient: supabaseClient);

    // Group by currency
    final Map<String, double> totals = {'USD': 0.0, 'CAD': 0.0};

    for (final entry in entries) {
      final cost = entry.totalCost;
      totals[entry.currency] = (totals[entry.currency] ?? 0) + cost;
    }

    return totals;
  }

  /// Get total fuel quantity
  static Future<Map<String, double>> getTotalFuelQuantity({
    SupabaseClient? supabaseClient,
  }) async {
    final entries = await getFuelEntries(supabaseClient: supabaseClient);

    // Group by unit
    final Map<String, double> totals = {'gal': 0.0, 'L': 0.0};

    for (final entry in entries) {
      totals[entry.fuelUnit] =
          (totals[entry.fuelUnit] ?? 0) + entry.fuelQuantity;
    }

    return totals;
  }

  /// Get truck fuel entries only
  static Future<List<FuelEntry>> getTruckFuelEntries({
    int? limit,
    SupabaseClient? supabaseClient,
  }) async {
    return getFuelEntries(
      limit: limit,
      fuelType: 'truck',
      supabaseClient: supabaseClient,
    );
  }

  /// Get reefer fuel entries only
  static Future<List<FuelEntry>> getReeferFuelEntries({
    int? limit,
    SupabaseClient? supabaseClient,
  }) async {
    return getFuelEntries(
      limit: limit,
      fuelType: 'reefer',
      supabaseClient: supabaseClient,
    );
  }

  /// Search fuel entries by truck/reefer number or location
  static Future<List<FuelEntry>> searchFuelEntries(
    String query, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('fuel_entries')
          .select()
          .eq('user_id', userId)
          .or(
            'truck_number.ilike.%$query%,reefer_number.ilike.%$query%,location.ilike.%$query%',
          )
          .order('fuel_date', ascending: false);

      return (response as List)
          .map((json) => FuelEntry.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search fuel entries: $e');
    }
  }
}
