import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:fpdart/fpdart.dart';

/// Service for managing trips in Supabase
class TripService {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Create a new trip
  static Future<Result<Trip>> createTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    // Duplicate check wrap
    final existsResult = await tripNumberExists(trip.tripNumber, supabaseClient: client);
    return existsResult.fold(
      (failure) => left(failure),
      (exists) async {
        if (exists) {
          return left(ValidationFailure('Trip number "${trip.tripNumber}" already exists'));
        }

        return netClient.query<Trip>(
          () async {
            final data = trip.toJson();
            data['user_id'] = userId;
            data.remove('id'); // Let database generate ID

            final response = await client
                .from('driver_trips')
                .insert(data)
                .select()
                .single();

            return Trip.fromJson(response);
          },
          operationName: 'TripService.createTrip',
        );
      },
    );
  }

  /// Check if a trip number already exists for the current user
  static Future<Result<bool>> tripNumberExists(
    String tripNumber, {
    String? excludeId,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<bool>(
      () async {
        var query = client
            .from('driver_trips')
            .select('id')
            .eq('user_id', userId)
            .eq('trip_number', tripNumber.toUpperCase())
            .isFilter('deleted_at', null);

        // Exclude specific trip ID (for updates)
        if (excludeId != null) {
          query = query.neq('id', excludeId);
        }

        final response = await query.maybeSingle();
        return response != null;
      },
      operationName: 'TripService.tripNumberExists',
    );
  }

  /// Get all trips for current user
  static Future<Result<List<Trip>>> getTrips({
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
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final networkClient = _getNetworkClient(client);
    final result = await networkClient.query<List<dynamic>>(
      () async {
        var query = client
            .from('driver_trips')
            .select()
            .eq('user_id', userId)
            .isFilter('deleted_at', null);

        if (fromDate != null) {
          query = query.gte('trip_date', fromDate.toIso8601String());
        }
        if (toDate != null) {
          query = query.lte('trip_date', toDate.toIso8601String());
        }

        final response = await query.order('trip_date', ascending: false);
        return response as List<dynamic>;
      },
      operationName: 'TripService.getTrips',
      coalesceKey: coalesceKey,
    );

    return result.map(
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
  static Future<Result<Trip?>> getTripById(
    String tripId, {
    String? coalesceKey,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final networkClient = _getNetworkClient(client);
    final result = await networkClient.query<Map<String, dynamic>?>(
      () async {
        final response = await client
            .from('driver_trips')
            .select()
            .eq('id', tripId)
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .maybeSingle();
        return response;
      },
      operationName: 'TripService.getTripById',
      coalesceKey: coalesceKey,
    );

    return result.map(
      (data) {
        if (data == null) return null;
        return Trip.fromJson(data);
      },
    );
  }

  /// Update an existing trip
  static Future<Result<Trip>> updateTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    if (trip.id == null) {
      return left(const ValidationFailure('Trip ID is required for update'));
    }

    final netClient = _getNetworkClient(client);

    final existsResult = await tripNumberExists(
      trip.tripNumber,
      excludeId: trip.id,
      supabaseClient: client,
    );

    return existsResult.fold(
      (failure) => left(failure),
      (exists) async {
        if (exists) {
          return left(ValidationFailure('Trip number "${trip.tripNumber}" already exists'));
        }

        return netClient.query<Trip>(
          () async {
            final data = trip.toJson();
            data['updated_at'] = DateTime.now().toIso8601String();

            final response = await client
                .from('driver_trips')
                .update(data)
                .eq('id', trip.id!)
                .eq('user_id', userId)
                .select()
                .single();

            return Trip.fromJson(response);
          },
          operationName: 'TripService.updateTrip',
        );
      },
    );
  }

  /// Delete a trip
  static Future<Result<Unit>> deleteTrip(
    String tripId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<Unit>(
      () async {
        await client
            .from('driver_trips')
            .delete()
            .eq('id', tripId)
            .eq('user_id', userId);
        return unit;
      },
      operationName: 'TripService.deleteTrip',
    );
  }

  /// Get total trips count for current user
  static Future<Result<int>> getTripsCount({SupabaseClient? supabaseClient}) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<int>(
      () async {
        final response = await client
            .from('driver_trips')
            .select()
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .count(CountOption.exact);

        return response.count;
      },
      operationName: 'TripService.getTripsCount',
    );
  }

  /// Get total distance for all trips (calculated on server)
  static Future<Result<double>> getTotalDistance({
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<double>(
      () async {
        final response = await client.rpc(
          'get_total_trip_distance',
          params: {'user_uuid': userId},
        );
        return (response as num?)?.toDouble() ?? 0.0;
      },
      operationName: 'TripService.getTotalDistance',
    );
  }

  /// Search trips by trip number or truck number
  static Future<Result<List<Trip>>> searchTrips(
    String query, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<List<Trip>>(
      () async {
        final response = await client
            .from('driver_trips')
            .select()
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .or('trip_number.ilike.%$query%,truck_number.ilike.%$query%')
            .order('trip_date', ascending: false);

        return (response as List).map((json) => Trip.fromJson(json)).toList();
      },
      operationName: 'TripService.searchTrips',
    );
  }

  /// Get the most recent active trip (trip without end odometer)
  /// Returns null if no active trip exists
  static Future<Result<Trip?>> getActiveTrip({SupabaseClient? supabaseClient}) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return left(const UnauthorizedFailure('User not authenticated'));
    }

    final netClient = _getNetworkClient(client);

    return netClient.query<Trip?>(
      () async {
        final response = await client
            .from('driver_trips')
            .select()
            .isFilter('deleted_at', null)
            .eq('user_id', userId)
            .isFilter('end_odometer', null)
            .order('trip_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response == null) return null;
        return Trip.fromJson(response);
      },
      operationName: 'TripService.getActiveTrip',
    );
  }
}
