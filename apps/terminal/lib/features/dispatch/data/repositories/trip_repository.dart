import 'package:fpdart/fpdart.dart';
import 'package:milow_core/milow_core.dart';

class TripRepository {
  final CoreNetworkClient _client;
  final String? companyId;

  TripRepository(this._client, {this.companyId});

  /// Fetch driver trips for the current company.
  /// Used by Terminal dispatchers to monitor offline-first driver activity.
  Future<Result<List<Trip>>> fetchTrips({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    if (companyId == null) {
      return left(ValidationFailure('No company ID available for trips query'));
    }

    return _client.query<List<Trip>>(() async {
      final start = page * pageSize;
      final end = start + pageSize - 1;

      var query = _client.supabase
          .from('driver_trips')
          .select()
          .eq('company_id', companyId!);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('trip_number', '%$searchQuery%');
      }

      final response = await query
          .order('trip_date', ascending: false)
          .range(start, end);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    }, operationName: 'fetchTrips');
  }
}
