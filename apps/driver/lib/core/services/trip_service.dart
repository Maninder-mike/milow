import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Service for managing trips in Supabase
class TripService {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Create a new trip
  static Future<Trip?> createTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Check for duplicate trip number
    if (await tripNumberExists(trip.tripNumber, supabaseClient: client)) {
      throw Exception('Trip number "${trip.tripNumber}" already exists');
    }

    try {
      final data = trip.toJson();
      data['user_id'] = userId;
      data.remove('id'); // Let database generate ID

      final response = await client
          .from('trips')
          .insert(data)
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
      // Rethrow all errors so ErrorHandler can parse them correctly
      rethrow;
    }
  }

  /// Check if a trip number already exists for the current user
  static Future<bool> tripNumberExists(
    String tripNumber, {
    String? excludeId,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      var query = client
          .from('trips')
          .select('id')
          .eq('user_id', userId)
          .eq('trip_number', tripNumber.toUpperCase());

      // Exclude specific trip ID (for updates)
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get all trips for current user
  static Future<List<Trip>> getTrips({
    int? limit,
    int? offset,
    DateTime? fromDate,
    DateTime? toDate,
    String? coalesceKey,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final networkClient = _getNetworkClient(client);
    final result = await networkClient.query(
      () async {
        var query = client.from('trips').select().eq('user_id', userId);

        if (fromDate != null) {
          query = query.gte('trip_date', fromDate.toIso8601String());
        }
        if (toDate != null) {
          query = query.lte('trip_date', toDate.toIso8601String());
        }

        final response = await query.order('trip_date', ascending: false);
        return response as List<dynamic>;
      },
      operationName: 'getTrips',
      coalesceKey: coalesceKey,
    );

    return result.fold(
      (failure) => throw Exception('Failed to get trips: ${failure.message}'),
      (data) {
        var list = data;
        if (limit != null) {
          list = list.take(limit).toList();
        }
        return list.map((json) => Trip.fromJson(json)).toList();
      },
    );
  }

  /// Get a single trip by ID
  static Future<Trip?> getTripById(
    String tripId, {
    String? coalesceKey,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final networkClient = _getNetworkClient(client);
    final result = await networkClient.query(
      () async {
        final response = await client
            .from('trips')
            .select()
            .eq('id', tripId)
            .eq('user_id', userId)
            .maybeSingle();
        return response;
      },
      operationName: 'getTripById',
      coalesceKey: coalesceKey,
    );

    return result.fold(
      (failure) => throw Exception('Failed to get trip: ${failure.message}'),
      (data) {
        if (data == null) return null;
        return Trip.fromJson(data);
      },
    );
  }

  /// Update an existing trip
  static Future<Trip?> updateTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (trip.id == null) {
      throw Exception('Trip ID is required for update');
    }

    // Check for duplicate trip number (excluding current trip)
    if (await tripNumberExists(
      trip.tripNumber,
      excludeId: trip.id,
      supabaseClient: client,
    )) {
      throw Exception('Trip number "${trip.tripNumber}" already exists');
    }

    try {
      final data = trip.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await client
          .from('trips')
          .update(data)
          .eq('id', trip.id!)
          .eq('user_id', userId)
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a trip
  static Future<void> deleteTrip(
    String tripId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await client
          .from('trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete trip: $e');
    }
  }

  /// Get total trips count for current user
  static Future<int> getTripsCount({SupabaseClient? supabaseClient}) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      throw Exception('Failed to get trips count: $e');
    }
  }

  /// Get total distance for all trips (calculated on server)
  static Future<double> getTotalDistance({
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client.rpc(
        'get_total_trip_distance',
        params: {'user_uuid': userId},
      );
      return (response as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      throw Exception('Failed to get total distance: $e');
    }
  }

  /// Search trips by trip number or truck number
  static Future<List<Trip>> searchTrips(
    String query, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .or('trip_number.ilike.%$query%,truck_number.ilike.%$query%')
          .order('trip_date', ascending: false);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search trips: $e');
    }
  }

  /// Get the most recent active trip (trip without end odometer)
  /// Returns null if no active trip exists
  static Future<Trip?> getActiveTrip({SupabaseClient? supabaseClient}) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .isFilter('end_odometer', null)
          .order('trip_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Trip.fromJson(response);
    } catch (e) {
      // Return null on error - active trip is optional
      return null;
    }
  }
}
