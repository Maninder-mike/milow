import 'package:milow_core/milow_core.dart';
import '../../domain/models/invoice.dart';

class InvoiceRepository {
  final CoreNetworkClient _client;

  InvoiceRepository(this._client);

  /// Fetch invoices from the database
  Future<Result<List<Invoice>>> fetchInvoices({
    int page = 0,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    return _client.query<List<Invoice>>(() async {
      final start = page * pageSize;
      final end = start + pageSize - 1;

      AppLogger.debug('Fetching invoices...');
      AppLogger.debug(
        'Current User ID: ${_client.supabase.auth.currentUser?.id}',
      );

      // 1. Fetch invoices with basic load details + IDs for pickups/receivers
      var query = _client.supabase.from('invoices').select('''
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

      AppLogger.debug(
        'Raw invoices response count: ${(response as List).length}',
      );

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
        AppLogger.debug('Fetching ${pickupIds.length} pickups manually');
        final pickups = await _client.supabase
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
        AppLogger.debug('Fetching ${receiverIds.length} receivers manually');
        final receivers = await _client.supabase
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
    }, operationName: 'fetchInvoices');
  }

  /// Create a new invoice
  Future<Result<void>> createInvoice(Invoice invoice) async {
    return _client.query<void>(() async {
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

      await _client.supabase.from('invoices').insert(data);
    }, operationName: 'createInvoice');
  }

  /// Update an existing invoice
  Future<Result<void>> updateInvoice(Invoice invoice) async {
    return _client.query<void>(() async {
      final data = invoice.toJson();
      data.remove('id');
      await _client.supabase.from('invoices').update(data).eq('id', invoice.id);
    }, operationName: 'updateInvoice');
  }

  /// Update invoice status
  Future<Result<void>> updateStatus(String id, String status) async {
    return _client.query<void>(() async {
      await _client.supabase
          .from('invoices')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    }, operationName: 'updateStatus');
  }

  /// Delete an invoice
  Future<Result<void>> deleteInvoice(String id) async {
    return _client.query<void>(() async {
      await _client.supabase.from('invoices').delete().eq('id', id);
    }, operationName: 'deleteInvoice');
  }

  /// Get next invoice number (simple sequential for now)
  Future<Result<String>> getNextInvoiceNumber() async {
    return _client.query<String>(
      () async {
        final response = await _client.supabase
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
      },
      operationName: 'getNextInvoiceNumber',
      // If it fails, default to sensible starting point?
      // Result type handles error, controller can decide fallback.
    );
  }
}
