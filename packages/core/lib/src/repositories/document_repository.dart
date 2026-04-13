import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fpdart/fpdart.dart';
import '../models/trip_document.dart';
import '../utils/failure.dart';
import '../services/core_network_client.dart';

/// Repository for handling formalized document workflows (approvals, status tracking)
class DocumentRepository {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Fetches documents for a specific user (Driver view)
  static Future<Result<List<TripDocument>>> getDocumentsForUser(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('documents')
          .select('*, driver_trips(trip_number)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return response;
    }, operationName: 'getDocumentsForUser');

    return result.fold((failure) => left(failure), (data) {
      try {
        final docs = (data as List)
            .map((json) => TripDocument.fromJson(json))
            .toList();
        return right(docs);
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Updates the status of a document (Approvals/Rejections)
  static Future<Result<TripDocument>> updateDocumentStatus({
    required String documentId,
    required DocumentStatus status,
    String? notes,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final user = client.auth.currentUser;

    if (user == null) {
      return left(UnauthorizedFailure('User not authenticated'));
    }

    // Since we want to use the document_reviews table for audit,
    // we should ideally do this in an Edge Function or a transaction.
    // For now, we'll perform two separate operations or a RPC if available.
    // Let's assume the client can handle it or we use RPC.

    final result = await _getNetworkClient(client).query(() async {
      // 1. Update document
      final updatedDoc = await client
          .from('documents')
          .update({
            'status': status.value,
            'review_notes': notes,
            'reviewed_by': user.id,
          })
          .eq('id', documentId)
          .select('*, driver_trips(trip_number)')
          .single();

      // 2. Insert review log (No await here to avoid blocking if not critical,
      // but the migration added RLS so we should probably await)
      await client.from('document_reviews').insert({
        'document_id': documentId,
        'reviewer_id': user.id,
        'company_id': updatedDoc['company_id'], // Get from updated doc
        'new_status': status.value,
        'notes': notes,
      });

      return updatedDoc;
    }, operationName: 'updateDocumentStatus');

    return result.fold((failure) => left(failure), (data) {
      try {
        return right(TripDocument.fromJson(data));
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Streams documents for a company (Dispatcher view)
  static Stream<List<TripDocument>> subscribeToPendingDocuments({
    required String companyId,
    SupabaseClient? supabaseClient,
  }) {
    final client = _getClient(supabaseClient);
    return client
        .from('documents')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .map((data) {
          final docs = data.map((json) => TripDocument.fromJson(json)).toList();
          return docs
              .where((doc) => doc.status == DocumentStatus.pending)
              .toList();
        });
  }
}
