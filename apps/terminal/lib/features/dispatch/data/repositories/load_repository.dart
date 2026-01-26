import 'package:fpdart/fpdart.dart';
import 'package:milow_core/milow_core.dart';
// Needed for Postgrest updates

import '../../domain/models/load.dart';

/// Repository for Load operations.
///
/// Uses [CoreNetworkClient] for resilient network calls and returns
/// [Result] types for structured error handling.
class LoadRepository {
  final CoreNetworkClient _client;

  LoadRepository(this._client);

  /// Fetch loads with related data (broker, stops).
  Future<Result<List<Load>>> fetchLoads({
    int page = 0,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    return _client.query<List<Load>>(() async {
      var query = _client.supabase.from('loads').select('''
          *,
          customers(name),
          stops(*),
          pickups(*),
          receivers(*)
        '''); // Fetching legacy pickups/receivers for backward compatibility

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end);

      return (response as List<dynamic>)
          .map((json) => Load.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchLoads');
  }

  /// Create a new load.
  /// Handles creating related entities (Broker) and Stops.
  Future<Result<void>> createLoad(Load load) async {
    // Validate required fields
    if (load.brokerName.isEmpty &&
        (load.brokerId == null || load.brokerId!.isEmpty)) {
      return left(const ValidationFailure('Broker name is required.'));
    }
    if (load.stops.isEmpty) {
      // Enforce at least 1 stop or relies on legacy?
      // Phase 4: Enforce Sequence.
      return left(const ValidationFailure('At least one stop is required.'));
    }

    return _client.query<void>(() async {
      AppLogger.debug('Creating load...');

      final companyId = await _getMyCompanyId();
      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['company_id'] = companyId;

      // Phase 4: Do NOT populate legacy pickup_id/receiver_id for new loads.
      // They are nullable.
      loadData.remove('pickup_id');
      loadData.remove('receiver_id');

      // Remove ID to let DB generate it
      loadData.remove('id');
      // Ensure timestamps are handled by DB
      loadData.remove('created_at');
      loadData.remove('updated_at');

      // Insert Load and get ID
      final response = await _client.supabase
          .from('loads')
          .insert(loadData)
          .select('id')
          .single();

      final newLoadId = response['id'] as String;

      // Insert Stops
      if (load.stops.isNotEmpty) {
        final stopsData = load.stops.map((stop) {
          final map = stop.toJson();
          map['load_id'] = newLoadId; // Link to new load
          map.remove('id'); // Generate new IDs
          return map;
        }).toList();

        await _client.supabase.from('stops').insert(stopsData);
      }

      AppLogger.info('Load created successfully ($newLoadId).');
    }, operationName: 'createLoad');
  }

  /// Update an existing load.
  Future<Result<void>> updateLoad(Load load) async {
    if (load.id.isEmpty) {
      return left(const ValidationFailure('Load ID is required for update.'));
    }

    return _client.query<void>(() async {
      AppLogger.debug('Updating load ${load.id}...');

      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['company_id'] = await _getMyCompanyId();

      // Keep legacy fields null/untouched if they aren't in toJson?
      // toJson sends them if ID present.
      // We should probably explicitly remove them to enforce Stop usage if we want migration.
      // But if we want to maintain legacy pointers, we'd need to update them.
      // For Phase 4.1: Ignore legacy columns during update.
      loadData.remove('pickup_id');
      loadData.remove('receiver_id');

      loadData.remove('id');
      loadData.remove('created_at');
      loadData.remove('updated_at');

      AppLogger.debug('Updating load ${load.id} with data: $loadData');

      final updateRes = await _client.supabase
          .from('loads')
          .update(loadData)
          .eq('id', load.id)
          .select();
      AppLogger.debug('Load update result: $updateRes');

      // Update Stops: Replace All Strategy
      // 1. Delete all stops for this load
      AppLogger.debug('Deleting existing stops for load ${load.id}');
      await _client.supabase.from('stops').delete().eq('load_id', load.id);

      // 2. Insert current stops
      if (load.stops.isNotEmpty) {
        final stopsData = load.stops.map((stop) {
          final map = stop.toJson();
          map['load_id'] = load.id;
          map.remove('id'); // Generate new IDs ensures clean slate
          return map;
        }).toList();

        AppLogger.debug(
          'Inserting ${stopsData.length} stops for load ${load.id}',
        );
        final insertRes = await _client.supabase
            .from('stops')
            .insert(stopsData)
            .select();
        AppLogger.debug('Stops insert result: $insertRes');
      }

      AppLogger.info('Load ${load.id} updated successfully.');
    }, operationName: 'updateLoad');
  }

  /// Delete a load by ID.
  Future<Result<void>> deleteLoad(String id) async {
    if (id.isEmpty) {
      return left(const ValidationFailure('Load ID is required for deletion.'));
    }

    return _client.query<void>(() async {
      // Cascade delete handles stops if defined in DB schema (ON DELETE CASCADE)
      await _client.supabase.from('loads').delete().eq('id', id);
      AppLogger.info('Load $id deleted successfully.');
    }, operationName: 'deleteLoad');
  }

  /// Fetches the most recent trip number and increments it if it's numeric.
  Future<Result<String?>> getNextTripNumber() async {
    return _client.query<String?>(() async {
      final response = await _client.supabase
          .from('loads')
          .select('trip_number')
          .not('trip_number', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['trip_number'] != null) {
        final lastTrip = response['trip_number'] as String;
        final val = int.tryParse(lastTrip);
        if (val != null) {
          return (val + 1).toString();
        }
      }
      return null;
    }, operationName: 'getNextTripNumber');
  }

  // --- Private Helpers ---

  /// Helper to get or create a broker.
  Future<String> _ensureBrokerExists(String? id, String name) async {
    if (id != null && id.isNotEmpty) return id;

    final existing = await _client.supabase
        .from('customers')
        .select('id')
        .eq('name', name)
        .eq('customer_type', 'Broker')
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final response = await _client.supabase
        .from('customers')
        .insert({
          'name': name,
          'customer_type': 'Broker',
          'address': '',
          'city': '',
          'state_province': '',
          'postal_code': '',
          'country': 'USA',
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Helper to get the current user's company ID.
  Future<String?> _getMyCompanyId() async {
    final user = _client.supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _client.supabase
        .from('profiles')
        .select('company_id')
        .eq('id', user.id)
        .maybeSingle();

    return response?['company_id'] as String?;
  }
}
