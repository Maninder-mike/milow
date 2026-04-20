import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for handling [Load] entities.
class LoadRepository {
  LoadRepository(this._client, {this.companyId});

  final CoreNetworkClient _client;
  final String? companyId; // Inject companyId

  /// Fetch paginated list of loads, optionally filtered by status and search query.
  Future<Result<List<Load>>> fetchLoads({
    required int page,
    required int pageSize,
    String? statusFilter,
    String? searchQuery,
  }) async {
    return _client.query<List<Load>>(() async {
      AppLogger.debug(
        'Fetching loads (page: $page, pageSize: $pageSize, search: $searchQuery)',
      );

      var query = _client.supabase.from('loads').select('''
          id, load_reference, status,
          trip_number, po_number, created_at, updated_at, broker_id, pickup_date, delivery_date,
          pickup_id, receiver_id, company_id,
          customers(*),
          stops(*),
          accessorials:accessorial_charges(*)
        ''');

      if (companyId != null) {
        query = query.eq('company_id', companyId!);
      }

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'trip_number.ilike.%$searchQuery%, load_reference.ilike.%$searchQuery%',
        );
      }

      final start = page * pageSize;
      final end = start + pageSize - 1;

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
      return left(const ValidationFailure('At least one stop is required.'));
    }

    final companyId = await _getMyCompanyId();
    if (companyId == null) {
      return left(
        const UnauthorizedFailure('Company ID not found. Please log in again.'),
      );
    }

    return _client.query<void>(() async {
      AppLogger.info('Creating load...');

      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['company_id'] = companyId;

      loadData.remove('pickup_id');
      loadData.remove('receiver_id');
      loadData.remove('id');
      loadData.remove('created_at');
      loadData.remove('updated_at');

      final accessorials = loadData.remove('accessorials') as List?;

      final response = await _client.supabase
          .from('loads')
          .insert(loadData)
          .select('id')
          .single();

      final newLoadId = response['id'] as String;

      if (load.stops.isNotEmpty) {
        final stopsData = load.stops.map((stop) {
          final map = stop.toJson();
          map['load_id'] = newLoadId;
          map.remove('id');
          return map;
        }).toList();

        await _client.supabase.from('stops').insert(stopsData);
      }

      if (accessorials != null && accessorials.isNotEmpty) {
        final accessorialsData = accessorials.map((e) {
          final map = e as Map<String, dynamic>;
          map['load_id'] = newLoadId;
          map.remove('id');
          return map;
        }).toList();

        await _client.supabase
            .from('accessorial_charges')
            .insert(accessorialsData);
      }

      AppLogger.info('Load created successfully ($newLoadId).');
    }, operationName: 'createLoad');
  }

  /// Update an existing load.
  Future<Result<void>> updateLoad(Load load) async {
    if (load.id.isEmpty) {
      return left(const ValidationFailure('Load ID is required for update.'));
    }

    final companyId = await _getMyCompanyId();
    if (companyId == null) {
      return left(const UnauthorizedFailure('Company ID not found.'));
    }

    return _client.query<void>(() async {
      AppLogger.info('Updating load ${load.id}...');

      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['company_id'] = companyId;

      loadData.remove('pickup_id');
      loadData.remove('receiver_id');
      loadData.remove('id');
      loadData.remove('created_at');
      loadData.remove('updated_at');

      final accessorials = loadData.remove('accessorials') as List?;

      await _client.supabase
          .from('loads')
          .update(loadData)
          .eq('id', load.id);

      await _client.supabase.from('stops').delete().eq('load_id', load.id);

      if (load.stops.isNotEmpty) {
        final stopsData = load.stops.map((stop) {
          final map = stop.toJson();
          map['load_id'] = load.id;
          map.remove('id');
          return map;
        }).toList();

        await _client.supabase.from('stops').insert(stopsData);
      }

      await _client.supabase
          .from('accessorial_charges')
          .delete()
          .eq('load_id', load.id);

      if (accessorials != null && accessorials.isNotEmpty) {
        final accessorialsData = accessorials.map((e) {
          final map = e as Map<String, dynamic>;
          map['load_id'] = load.id;
          map.remove('id');
          return map;
        }).toList();

        await _client.supabase
            .from('accessorial_charges')
            .insert(accessorialsData);
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

  /// Fetch all documents for a specific load.
  Future<Result<List<LoadDocument>>> fetchDocumentsForLoad(String loadId) async {
    return _client.query<List<LoadDocument>>(() async {
      final response = await _client.supabase
          .from('documents')
          .select()
          .eq('load_id', loadId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => LoadDocument.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchDocumentsForLoad');
  }

  /// Fetch check-calls for a load
  Future<Result<List<CheckCall>>> fetchCheckCallsForLoad(String loadId) async {
    return _client.query<List<CheckCall>>(() async {
      final response = await _client.supabase
          .from('check_calls')
          .select()
          .eq('load_id', loadId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CheckCall.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchCheckCallsForLoad');
  }

  /// Create a new check-call request
  Future<Result<CheckCall>> createCheckCall({
    required String loadId,
    required String driverId,
    required CheckCallType type,
    required String prompt,
    Map<String, dynamic>? options,
    DateTime? expiresAt,
  }) async {
    final user = _client.supabase.auth.currentUser;
    if (user == null) return left(UnauthorizedFailure());

    return _client.query<CheckCall>(() async {
      final loadData = await _client.supabase
          .from('loads')
          .select('company_id')
          .eq('id', loadId)
          .single();

      final response = await _client.supabase
          .from('check_calls')
          .insert({
            'load_id': loadId,
            'company_id': loadData['company_id'],
            'driver_id': driverId,
            'requester_id': user.id,
            'type': type.value,
            'prompt': prompt,
            'options': options,
            'expires_at': expiresAt?.toIso8601String(),
            'status': 'pending',
          })
          .select()
          .single();

      return CheckCall.fromJson(response);
    }, operationName: 'createCheckCall');
  }

  /// Update document status (Approve/Reject).
  Future<Result<void>> updateDocumentStatus(
    String documentId,
    String status, {
    String? rejectionReason,
  }) async {
    return _client.query<void>(() async {
      await _client.supabase.from('documents').update({
        'status': status,
        'rejection_reason': rejectionReason,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': _client.supabase.auth.currentUser?.id,
      }).eq('id', documentId);
    }, operationName: 'updateDocumentStatus');
  }

  /// Fetch pickup location suggestions
  Future<Result<List<Map<String, dynamic>>>> fetchPickupSuggestions() async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final response = await _client.supabase
          .from('pickups')
          .select('id, shipper_name, address, city, state_province, postal_code, contact_person, phone, fax')
          .order('shipper_name');
      return (response as List).cast<Map<String, dynamic>>();
    }, operationName: 'fetchPickupSuggestions');
  }

  /// Fetch receiver location suggestions
  Future<Result<List<Map<String, dynamic>>>> fetchReceiverSuggestions() async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final response = await _client.supabase
          .from('receivers')
          .select('id, receiver_name, address, city, state_province, postal_code, contact_person, phone, fax')
          .order('receiver_name');
      return (response as List).cast<Map<String, dynamic>>();
    }, operationName: 'fetchReceiverSuggestions');
  }

  /// Fetch broker customer suggestions
  Future<Result<List<Map<String, dynamic>>>> fetchBrokerSuggestions() async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final response = await _client.supabase
          .from('customers')
          .select('id, name, city, state_province')
          .eq('customer_type', 'Broker')
          .order('name');
      return (response as List).cast<Map<String, dynamic>>();
    }, operationName: 'fetchBrokerSuggestions');
  }

  /// Upsert fleet assignments for a load.
  Future<Result<void>> upsertFleetAssignments(List<Map<String, dynamic>> assignments) async {
    if (assignments.isEmpty) return right(null);

    return _client.query<void>(() async {
      await _client.supabase.from('fleet_assignments').upsert(
            assignments,
            onConflict: 'assignee_id, trip_number, type',
          );
    }, operationName: 'upsertFleetAssignments');
  }

  /// Stream that emits when the 'loads' table changes for the current company.
  Stream<int> get loadsChangeSignal {
    final controller = StreamController<int>();
    int counter = 0;

    if (companyId == null) return const Stream.empty();

    final channel = _client.supabase.channel('public:loads:$companyId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId!,
          ),
          callback: (payload) {
            counter++;
            if (!controller.isClosed) controller.add(counter);
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Stream that emits when the 'stops' table changes.
  Stream<int> get stopsChangeSignal {
    final controller = StreamController<int>();
    int counter = 0;

    if (companyId == null) return const Stream.empty();

    final channel = _client.supabase.channel('public:stops:$companyId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stops',
          callback: (payload) {
            counter++;
            if (!controller.isClosed) controller.add(counter);
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Fetch summary statistics for loads.
  Future<Result<Map<String, int>>> fetchLoadStats() async {
    return _client.query<Map<String, int>>(() async {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      var baseQuery = _client.supabase.from('loads').select('id');
      if (companyId != null) {
        baseQuery = baseQuery.eq('company_id', companyId!);
      }

      final results = await Future.wait([
        // Today
        baseQuery
            .gte('pickup_date', startOfDay)
            .lte('pickup_date', endOfDay)
            .count(CountOption.exact),
        // Active
        baseQuery
            .inFilter('status', [
              'assigned', 'dispatched', 'tendered', 'enRoute', 
              'atPickup', 'loaded', 'atStop', 'atDelivery'
            ])
            .count(CountOption.exact),
        // Completed
        baseQuery
            .inFilter('status', ['delivered', 'completed'])
            .count(CountOption.exact),
        // Delayed
        baseQuery
            .eq('is_delayed', true)
            .count(CountOption.exact),
      ]);

      return {
        'today': results[0].count,
        'active': results[1].count,
        'completed': results[2].count,
        'delayed': results[3].count,
      };
    }, operationName: 'fetchLoadStats');
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

    final result = await _client.query<String?>(
      () async {
        final response = await _client.supabase
            .from('profiles')
            .select('company_id')
            .eq('id', user.id)
            .maybeSingle();
        return response?['company_id'] as String?;
      },
      operationName: 'getMyCompanyId',
      cachePolicy: CachePolicy.cacheFirst,
      cacheKey: 'user_company_id_${user.id}',
      ttl: const Duration(hours: 1),
    );

    return result.getOrElse((failure) => null);
  }
}
