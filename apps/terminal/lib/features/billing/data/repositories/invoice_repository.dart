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

    var query = _supabase
        .from('invoices')
        .select('*, customers(name), loads(load_reference)');

    if (statusFilter != null && statusFilter != 'All') {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end);

    return (response as List<dynamic>)
        .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new invoice
  Future<void> createInvoice(Invoice invoice) async {
    try {
      final data = invoice.toJson();
      // Remove ID to let DB generate it if it's empty
      if (invoice.id.isEmpty) {
        data.remove('id');
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
