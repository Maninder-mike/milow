import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/quote.dart';

class QuoteRepository {
  final SupabaseClient _supabase;

  QuoteRepository(this._supabase);

  /// Fetch all quotes with optional status filter
  Future<List<Quote>> fetchQuotes({String? statusFilter}) async {
    var query = _supabase.from('quotes').select('''
      *,
      loads!inner(load_reference)
    ''');

    if (statusFilter != null && statusFilter != 'All') {
      query = query.eq('status', statusFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List<dynamic>).map((json) {
      final loadData = json['loads'] as Map<String, dynamic>?;
      final quoteJson = Map<String, dynamic>.from(json);
      quoteJson['load_reference'] = loadData?['load_reference'] ?? '';
      return Quote.fromJson(quoteJson);
    }).toList();
  }

  /// Fetch quotes for a specific load
  Future<List<Quote>> fetchQuotesForLoad(String loadId) async {
    final response = await _supabase
        .from('quotes')
        .select()
        .eq('load_id', loadId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Quote.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new quote
  Future<void> createQuote(Quote quote) async {
    try {
      final quoteData = quote.toJson();
      quoteData.remove('id');
      quoteData.remove('created_at');
      quoteData.remove('updated_at');

      await _supabase.from('quotes').insert(quoteData);
    } catch (e) {
      debugPrint('Error creating quote: $e');
      rethrow;
    }
  }

  /// Update an existing quote
  Future<void> updateQuote(Quote quote) async {
    try {
      final quoteData = quote.toJson();
      quoteData.remove('id');
      quoteData.remove('created_at');
      quoteData.remove('updated_at');

      await _supabase.from('quotes').update(quoteData).eq('id', quote.id);
    } catch (e) {
      debugPrint('Error updating quote: $e');
      rethrow;
    }
  }

  /// Delete a quote
  Future<void> deleteQuote(String id) async {
    await _supabase.from('quotes').delete().eq('id', id);
  }
}
