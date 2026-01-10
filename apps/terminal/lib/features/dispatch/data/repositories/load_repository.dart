import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/load.dart';

class LoadRepository {
  final SupabaseClient _supabase;

  LoadRepository(this._supabase);

  /// Fetch loads with related data (broker, pickup, receiver)
  Future<List<Load>> fetchLoads({
    int page = 0,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    var query = _supabase.from('loads').select('''
          *,
          customers(name),
          pickups(*),
          receivers(*)
        ''');

    if (statusFilter != null && statusFilter != 'All') {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end);

    return (response as List<dynamic>)
        .map((json) => Load.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new load.
  /// Handles creating related entities (Broker, Pickup, Receiver) if they don't exist.
  Future<void> createLoad(Load load) async {
    try {
      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );
      final pickupId = await _ensurePickupExists(load.pickup);
      final receiverId = await _ensureReceiverExists(load.delivery);

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['pickup_id'] = pickupId;
      loadData['receiver_id'] = receiverId;

      // Remove ID to let DB generate it
      loadData.remove('id');

      // Ensure timestamps are handled by DB or set here
      // DB defaults created_at to now(), updated_at via trigger.
      loadData.remove('created_at');
      loadData.remove('updated_at');

      await _supabase.from('loads').insert(loadData);
    } catch (e) {
      debugPrint('Error creating load: $e');
      rethrow;
    }
  }

  /// Update an existing load.
  /// Handles creating related entities if they changed to new ones.
  Future<void> updateLoad(Load load) async {
    try {
      debugPrint('LoadRepository: Updating load ${load.id}...');
      final brokerId = await _ensureBrokerExists(
        load.brokerId,
        load.brokerName,
      );
      debugPrint('LoadRepository: Broker ensured ($brokerId)');
      final pickupId = await _ensurePickupExists(load.pickup);
      debugPrint('LoadRepository: Pickup ensured ($pickupId)');
      final receiverId = await _ensureReceiverExists(load.delivery);
      debugPrint('LoadRepository: Receiver ensured ($receiverId)');

      final loadData = load.toJson();
      loadData['broker_id'] = brokerId;
      loadData['pickup_id'] = pickupId;
      loadData['receiver_id'] = receiverId;

      // Remove fields that shouldn't be updated manually or are managed
      loadData.remove('id');
      loadData.remove('created_at');
      loadData.remove('updated_at');

      debugPrint('LoadRepository: Performing update query...');
      await _supabase.from('loads').update(loadData).eq('id', load.id);
      debugPrint('LoadRepository: Update complete');
    } catch (e) {
      debugPrint('Error updating load: $e');
      rethrow;
    }
  }

  /// Helper to get or create a broker
  Future<String> _ensureBrokerExists(String? id, String name) async {
    if (id != null && id.isNotEmpty) return id;
    if (name.isEmpty) throw Exception('Broker name is required');

    // Check if exists by name to avoid duplicates
    final existing = await _supabase
        .from('customers')
        .select('id')
        .eq('name', name)
        .eq('customer_type', 'Broker')
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    // Create new broker
    final response = await _supabase
        .from('customers')
        .insert({
          'name': name,
          'customer_type': 'Broker',
          // Defaults for other fields
          'address': '',
          'city': '',
          'state_province': '',
          'postal_code': '',
          'country': 'USA', // Default
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Helper to get or create a pickup location
  Future<String> _ensurePickupExists(LoadLocation location) async {
    if (location.id != null && location.id!.isNotEmpty) return location.id!;
    if (location.companyName.isEmpty) {
      throw Exception('Pickup company name is required');
    }

    // Create new pickup
    final response = await _supabase
        .from('pickups')
        .insert({
          'shipper_name': location.companyName,
          'address': location.address,
          'city': location.city,
          'state_province': location.state,
          'postal_code': location.zipCode,
          'contact_person': location.contactName,
          'phone': location.contactPhone,
          'fax': location.contactFax,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Helper to get or create a receiver
  Future<String> _ensureReceiverExists(LoadLocation location) async {
    if (location.id != null && location.id!.isNotEmpty) return location.id!;
    if (location.companyName.isEmpty) {
      throw Exception('Receiver company name is required');
    }

    // Create new receiver
    final response = await _supabase
        .from('receivers')
        .insert({
          'receiver_name': location.companyName,
          'address': location.address,
          'city': location.city,
          'state_province': location.state,
          'postal_code': location.zipCode,
          'contact_person': location.contactName,
          'phone': location.contactPhone,
          'fax': location.contactFax,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> deleteLoad(String id) async {
    await _supabase.from('loads').delete().eq('id', id);
  }

  /// Fetches the most recent trip number and increments it if it's numeric.
  Future<String?> getNextTripNumber() async {
    try {
      final response = await _supabase
          .from('loads')
          .select('trip_number')
          .not('trip_number', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['trip_number'] != null) {
        final lastTrip = response['trip_number'] as String;
        // Try to parse as int and increment
        final val = int.tryParse(lastTrip);
        if (val != null) {
          return (val + 1).toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching next trip number: $e');
      return null;
    }
  }
}
