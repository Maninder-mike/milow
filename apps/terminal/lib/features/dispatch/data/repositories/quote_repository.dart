import 'package:fpdart/fpdart.dart';
import 'package:milow_core/milow_core.dart';

import '../../domain/models/quote.dart';

class QuoteRepository {
  final CoreNetworkClient _client;

  QuoteRepository(this._client);

  /// Fetch all quotes with optional status filter
  Future<Result<List<Quote>>> fetchQuotes({String? statusFilter}) async {
    return _client.query<List<Quote>>(() async {
      var query = _client.supabase.from('quotes').select('''
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
    }, operationName: 'fetchQuotes');
  }

  /// Fetch quotes for a specific load
  Future<Result<List<Quote>>> fetchQuotesForLoad(String loadId) async {
    return _client.query<List<Quote>>(() async {
      final response = await _client.supabase
          .from('quotes')
          .select()
          .eq('load_id', loadId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Quote.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchQuotesForLoad');
  }

  /// Create a new quote
  Future<Result<void>> createQuote(Quote quote) async {
    return _client.query<void>(() async {
      final quoteData = quote.toJson();
      quoteData.remove('id');
      quoteData.remove('created_at');
      quoteData.remove('updated_at');

      await _client.supabase.from('quotes').insert(quoteData);
    }, operationName: 'createQuote');
  }

  /// Update an existing quote
  Future<Result<void>> updateQuote(Quote quote) async {
    if (quote.id.isEmpty) {
      return left(const ValidationFailure('Quote ID is required for update.'));
    }
    return _client.query<void>(() async {
      final quoteData = quote.toJson();
      quoteData.remove('id');
      quoteData.remove('created_at');
      quoteData.remove('updated_at');

      await _client.supabase
          .from('quotes')
          .update(quoteData)
          .eq('id', quote.id);
    }, operationName: 'updateQuote');
  }

  /// Delete a quote
  Future<Result<void>> deleteQuote(String id) async {
    return _client.query<void>(() async {
      await _client.supabase.from('quotes').delete().eq('id', id);
    }, operationName: 'deleteQuote');
  }

  /// Update just the status of a quote
  Future<Result<void>> updateStatus(String id, String status) async {
    return _client.query<void>(() async {
      await _client.supabase
          .from('quotes')
          .update({'status': status})
          .eq('id', id);
    }, operationName: 'updateStatus');
  }

  /// Fetch a single quote by ID
  Future<Result<Quote?>> fetchQuoteById(String id) async {
    return _client.query<Quote?>(() async {
      final response = await _client.supabase
          .from('quotes')
          .select('''
              *,
              loads!inner(load_reference)
            ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final loadData = response['loads'] as Map<String, dynamic>?;
      final quoteJson = Map<String, dynamic>.from(response);
      quoteJson['load_reference'] = loadData?['load_reference'] ?? '';
      return Quote.fromJson(quoteJson);
    }, operationName: 'fetchQuoteById');
  }
}
