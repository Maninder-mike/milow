import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/models/trip.dart';

/// Service for managing trips in Supabase
class TripService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => _client.auth.currentUser?.id;

  /// Create a new trip
  static Future<Trip?> createTrip(Trip trip) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Check for duplicate trip number
    if (await tripNumberExists(trip.tripNumber)) {
      throw Exception('Trip number "${trip.tripNumber}" already exists');
    }

    try {
      final data = trip.toJson();
      data['user_id'] = userId;
      data.remove('id'); // Let database generate ID

      final response = await _client
          .from('trips')
          .insert(data)
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
      throw Exception('Failed to create trip: $e');
    }
  }

  /// Check if a trip number already exists for the current user
  static Future<bool> tripNumberExists(
    String tripNumber, {
    String? excludeId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      var query = _client
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
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      var query = _client.from('trips').select().eq('user_id', userId);

      if (fromDate != null) {
        query = query.gte('trip_date', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('trip_date', toDate.toIso8601String());
      }

      final response = await query.order('trip_date', ascending: false);

      List<dynamic> data = response;
      if (limit != null) {
        data = data.take(limit).toList();
      }

      return data.map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get trips: $e');
    }
  }

  /// Get a single trip by ID
  static Future<Trip?> getTripById(String tripId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Trip.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get trip: $e');
    }
  }

  /// Update an existing trip
  static Future<Trip?> updateTrip(Trip trip) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (trip.id == null) {
      throw Exception('Trip ID is required for update');
    }

    // Check for duplicate trip number (excluding current trip)
    if (await tripNumberExists(trip.tripNumber, excludeId: trip.id)) {
      throw Exception('Trip number "${trip.tripNumber}" already exists');
    }

    try {
      final data = trip.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('trips')
          .update(data)
          .eq('id', trip.id!)
          .eq('user_id', userId)
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
      throw Exception('Failed to update trip: $e');
    }
  }

  /// Delete a trip
  static Future<void> deleteTrip(String tripId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _client
          .from('trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete trip: $e');
    }
  }

  /// Get total trips count for current user
  static Future<int> getTripsCount() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      throw Exception('Failed to get trips count: $e');
    }
  }

  /// Get total distance for all trips (in user's preferred unit)
  static Future<double> getTotalDistance() async {
    final trips = await getTrips();
    double total = 0;
    for (final trip in trips) {
      if (trip.totalDistance != null) {
        total += trip.totalDistance!;
      }
    }
    return total;
  }

  /// Search trips by trip number or truck number
  static Future<List<Trip>> searchTrips(String query) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
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
}
