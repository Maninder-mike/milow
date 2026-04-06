import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/local_load_document_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoadDocumentRepository {
  static SupabaseClient _getClient(SupabaseClient? client) =>
      client ?? Supabase.instance.client;

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) =>
      CoreNetworkClient(client);

  static String? _getUserId(SupabaseClient client) =>
      client.auth.currentUser?.id;

  /// Fetch documents for a specific load
  static Future<Result<List<LoadDocument>>> getDocumentsForLoad(
    String loadId, {
    SupabaseClient? supabaseClient,
    bool forceRefresh = false,
  }) async {
    final client = _getClient(supabaseClient);

    // Check offline cache first
    if (!forceRefresh) {
      final cached = LocalLoadDocumentStore.getForLoad(loadId);
      if (cached.isNotEmpty) {
        return Right(cached);
      }
    }

    if (!connectivityService.isOnline) {
      return Right(LocalLoadDocumentStore.getForLoad(loadId));
    }

    // Fetch from server
    return _getNetworkClient(client).query<List<LoadDocument>>(() async {
      final response = await client
          .from('documents')
          .select()
          .eq('load_id', loadId);
      
      final docs = (response as List)
          .map((data) => LoadDocument.fromJson(data as Map<String, dynamic>))
          .toList();

      // Update cache
      await LocalLoadDocumentStore.putAll(docs);
      return docs;
    }, operationName: 'getDocumentsForLoad');
  }

  /// Upload a document (offline capable)
  static Future<Result<void>> uploadDocument({
    required File file,
    required TripDocumentType type,
    required String loadId,
    required String loadReference, // Used for filename
    required String notes,
    String? stopId,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return const Left(UnauthorizedFailure());

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final shortType = type.name.toUpperCase().substring(0, 3);
    final extension = file.path.split('.').last.toLowerCase();
    final fileName = '$shortType-$loadReference-$dateStr.$extension';
    final storagePath = '$userId/$loadId/$fileName';
    final mimeType = extension == 'pdf' ? 'application/pdf' : 'image/$extension';

    // Generate local ID and save as pending upload
    final localId = const Uuid().v4();
    final localDoc = LoadDocument(
      id: localId,
      loadId: loadId,
      stopId: stopId,
      userId: userId,
      companyId: null, // Depending on if company id is retrievable here
      documentType: type,
      filePath: storagePath,
      fileName: fileName,
      fileSize: await file.length(),
      mimeType: mimeType,
      notes: notes,
      status: DocumentStatus.pendingUpload,
      createdAt: DateTime.now(),
    );

    // Persist immediately for UI visibility
    await LocalLoadDocumentStore.put(localDoc);

    if (!connectivityService.isOnline) {
      // Offline: Enqueue document upload Job
      debugPrint('[LoadDocumentRepository] Enqueueing document upload offline...');
      await syncQueueService.enqueue(
        tableName: 'documents',
        operationType: 'upload',
        payload: {
          'id': localId,
          'load_id': loadId,
          'stop_id': stopId,
          'file_path': file.path,
          'storage_path': storagePath,
          'document_type': type.value,
          'notes': notes,
          'file_name': fileName,
        },
        localId: localId,
      );
      return const Right(null);
    }

    return _getNetworkClient(client).query(() async {
      try {
        final bytes = await file.readAsBytes();

        // 1. Upload to Storage
        await client.storage.from('documents').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );

        // 2. Refresh Public URL
        final url = client.storage.from('documents').getPublicUrl(storagePath);

        // 3. Update Database (which triggers load_event and changes status)
        final dbResponse = await client.from('documents').insert({
          'load_id': loadId,
          'stop_id': stopId,
          'driver_id': userId,
          'document_type': type.value,
          'file_path': url,
          'file_name': fileName,
          'file_size': await file.length(),
          'mime_type': mimeType,
          'notes': notes,
          'status': DocumentStatus.pending.name,
        }).select().single();

        // 4. Update local cache with real ID and URL
        final serverDoc = LoadDocument.fromJson(dbResponse);
        // Remove pending local doc
        await LocalLoadDocumentStore.delete(localId);
        // Insert remote doc
        await LocalLoadDocumentStore.put(serverDoc);

      } catch (e) {
        debugPrint('[LoadDocumentRepository] Online upload failed, queueing... $e');
        // Mark failed
        await LocalLoadDocumentStore.put(
          LoadDocument(
            id: localDoc.id,
            loadId: localDoc.loadId,
            stopId: localDoc.stopId,
            userId: localDoc.userId,
            documentType: localDoc.documentType,
            filePath: localDoc.filePath,
            fileName: localDoc.fileName,
            notes: localDoc.notes,
            status: DocumentStatus.uploadFailed,
          ),
        );
        // We could also auto-enqueue here if we want automatic retries
        rethrow; // Rely on NetworkClient for error handling
      }
    }, operationName: 'uploadLoadDocument');
  }

  /// Delete documents
  static Future<Result<void>> deleteDocuments(
    List<LoadDocument> docs, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    return _getNetworkClient(client).query(() async {
      final filePaths = docs
          .map((d) => d.filePath)
          .where((path) => path.isNotEmpty && !path.startsWith('http')) 
          .toList(); // Note: if filePath is a public URL, we might need a way to extract storage path
      
      final idsToDelete = docs.map((d) => d.id).whereType<String>().toList();

      if (filePaths.isNotEmpty) {
        await client.storage.from('documents').remove(filePaths);
      }
      await client.from('documents').delete().inFilter('id', idsToDelete);
      
      for (final id in idsToDelete) {
        await LocalLoadDocumentStore.delete(id);
      }
    }, operationName: 'deleteDocuments');
  }
}
