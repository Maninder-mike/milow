import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/invoice.dart';

class InvoiceRepository {
  final SupabaseClient _supabase;

  InvoiceRepository(this._supabase);

  /// Fetch invoices from the database
  Future<List<Invoice>> fetchInvoices({
    int page = 0,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    debugPrint('Fetching invoices...');
    debugPrint('Current User ID: ${_supabase.auth.currentUser?.id}');
    try {
      // 1. Fetch invoices with basic load details + IDs for pickups/receivers
      // removing the deep nested 'pickups(...)' and 'receivers(...)' to avoid failure
      // adding pickup_id and receiver_id relative to loads
      var query = _supabase.from('invoices').select('''
            *,
            customers(id, name, address_line1, city, state_province, postal_code),
            loads(
              id, load_reference, po_number, goods, weight, weight_unit, pickup_date, delivery_date,
              pickup_id, receiver_id,
              customer:customers!loads_broker_id_fkey(id, name, address_line1, city, state_province, postal_code)
            )
          ''');

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end);

      debugPrint('Raw invoices response count: ${(response as List).length}');

      // 2. Identify required Pickup/Receiver IDs
      final dataList = List<Map<String, dynamic>>.from(response);
      final pickupIds = <String>{};
      final receiverIds = <String>{};

      for (var invoice in dataList) {
        final load = invoice['loads'] as Map<String, dynamic>?;
        if (load != null) {
          if (load['pickup_id'] != null) pickupIds.add(load['pickup_id']);
          if (load['receiver_id'] != null) receiverIds.add(load['receiver_id']);
        }
      }

      // 3. Explicitly Fetch Pickups in Batch
      Map<String, dynamic> pickupsMap = {};
      if (pickupIds.isNotEmpty) {
        debugPrint('Fetching ${pickupIds.length} pickups manually');
        final pickups = await _supabase
            .from('pickups')
            .select('*')
            .filter('id', 'in', pickupIds.toList());
        for (var p in pickups) {
          pickupsMap[p['id']] = p;
        }
      }

      // 4. Explicitly Fetch Receivers in Batch
      Map<String, dynamic> receiversMap = {};
      if (receiverIds.isNotEmpty) {
        debugPrint('Fetching ${receiverIds.length} receivers manually');
        final receivers = await _supabase
            .from('receivers')
            .select('*')
            .filter('id', 'in', receiverIds.toList());
        for (var r in receivers) {
          receiversMap[r['id']] = r;
        }
      }

      // 5. Stitch Nested Data Back
      for (var invoice in dataList) {
        final load = invoice['loads'] as Map<String, dynamic>?;
        if (load != null) {
          final pId = load['pickup_id'];
          final rId = load['receiver_id'];

          if (pId != null && pickupsMap.containsKey(pId)) {
            // Injecting 'pickups' key matching what fromJson looks for
            load['pickups'] = pickupsMap[pId];
          }
          if (rId != null && receiversMap.containsKey(rId)) {
            load['receivers'] = receiversMap[rId];
          }
        }
      }

      return dataList.map((json) => Invoice.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      rethrow;
    }
  }

  /// Create a new invoice
  Future<void> createInvoice(Invoice invoice) async {
    try {
      final data = invoice.toJson();
      // Remove ID to let DB generate it if it's empty
      if (invoice.id.isEmpty) {
        data.remove('id');
      }
      if (invoice.customerId == null || invoice.customerId!.isEmpty) {
        data['customer_id'] = null;
      }
      if (invoice.loadId.isEmpty) {
        data['load_id'] = null;
      }

      await _supabase.from('invoices').insert(data);
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      rethrow;
    }
  }

  /// Update an existing invoice
  Future<void> updateInvoice(Invoice invoice) async {
    try {
      final data = invoice.toJson();
      data.remove('id');
      await _supabase.from('invoices').update(data).eq('id', invoice.id);
    } catch (e) {
      debugPrint('Error updating invoice: $e');
      rethrow;
    }
  }

  /// Update invoice status
  Future<void> updateStatus(String id, String status) async {
    try {
      await _supabase
          .from('invoices')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
      rethrow;
    }
  }

  /// Delete an invoice
  Future<void> deleteInvoice(String id) async {
    await _supabase.from('invoices').delete().eq('id', id);
  }

  /// Get next invoice number (simple sequential for now)
  Future<String> getNextInvoiceNumber() async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('invoice_number')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['invoice_number'] != null) {
        final lastNum = response['invoice_number'] as String;
        // Basic parsing: INV-1001 -> 1002
        final match = RegExp(r'\d+').firstMatch(lastNum);
        if (match != null) {
          final val = int.parse(match.group(0)!);
          return 'INV-${(val + 1).toString().padLeft(4, '0')}';
        }
      }
      return 'INV-1001';
    } catch (e) {
      debugPrint('Error getting next invoice number: $e');
      return 'INV-1001';
    }
  }
}
