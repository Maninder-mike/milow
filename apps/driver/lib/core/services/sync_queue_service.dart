import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:milow/core/models/sync_operation.dart';
import 'package:milow/core/models/sync_status.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow_core/milow_core.dart';

/// Service for managing the offline sync queue.
///
/// Queues operations when offline and processes them when connectivity
/// returns. Uses exponential backoff for retries.
class SyncQueueService {
  static SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  /// Allow overriding the instance for tests
  @visibleForTesting
  static set instance(SyncQueueService mock) => _instance = mock;

  static SyncQueueService get instance => _instance;

  static const String _boxName = 'sync_queue';
  static const _uuid = Uuid();

  Box<SyncOperation>? _box;
  final _statusController = StreamController<SyncStatusInfo>.broadcast();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isProcessing = false;

  /// Stream of sync status updates
  Stream<SyncStatusInfo> get syncStatus => _statusController.stream;

  /// Number of pending operations
  int get pendingCount =>
      _box?.values.where((op) => op.status == 'pending').length ?? 0;

  /// Number of failed operations
  int get failedCount =>
      _box?.values.where((op) => op.status == 'failed').length ?? 0;

  /// All pending operations (for debugging/UI)
  List<SyncOperation> get pendingOperations =>
      _box?.values.where((op) => op.status == 'pending').toList() ?? [];

  /// All failed operations (for debugging/UI)
  List<SyncOperation> get failedOperations =>
      _box?.values.where((op) => op.status == 'failed').toList() ?? [];

  /// Initialize the sync queue service
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SyncOperationAdapter());
    }
    _box = await Hive.openBox<SyncOperation>(_boxName);

    // Listen for connectivity changes
    _connectivitySubscription = connectivityService.onConnectivityChanged
        .listen((isOnline) {
          if (isOnline) {
            debugPrint('[SyncQueueService] Online - processing queue');
            processQueue();
          } else {
            _emitStatus();
          }
        });

    // Process any pending items if online
    if (connectivityService.isOnline) {
      unawaited(processQueue());
    } else {
      _emitStatus();
    }

    debugPrint('[SyncQueueService] Initialized, pending: $pendingCount');
  }

  /// Enqueue a new sync operation
  Future<String> enqueue({
    required String tableName,
    required String operationType,
    required Map<String, dynamic> payload,
    required String localId,
  }) async {
    final box = _ensureBox;
    final id = _uuid.v4();

    final operation = SyncOperation(
      id: id,
      tableName: tableName,
      operationType: operationType,
      payload: json.encode(payload),
      createdAt: DateTime.now(),
      localId: localId,
    );

    await box.put(id, operation);
    debugPrint('[SyncQueueService] Enqueued: $operation');

    _emitStatus();

    // Try to process immediately if online
    if (connectivityService.isOnline && !_isProcessing) {
      unawaited(processQueue());
    }

    return id;
  }

  /// Process all pending operations in the queue
  Future<void> processQueue({SupabaseClient? supabaseClient}) async {
    if (_isProcessing) return;
    if (!connectivityService.isOnline) {
      _emitStatus();
      return;
    }

    final box = _ensureBox;
    final pending = box.values.where((op) => op.status == 'pending').toList();

    if (pending.isEmpty) {
      _emitStatus();
      return;
    }

    _isProcessing = true;
    _statusController.add(SyncStatusInfo.syncing(pending.length));

    for (final operation in pending) {
      // Check backoff delay
      if (operation.retryCount > 0) {
        final nextRetryTime = operation.createdAt.add(operation.backoffDelay);
        if (DateTime.now().isBefore(nextRetryTime)) {
          continue; // Skip, not ready for retry yet
        }
      }

      await _processOperation(operation, supabaseClient: supabaseClient);
    }

    _isProcessing = false;
    _emitStatus();
  }

  Future<void> _processOperation(
    SyncOperation operation, {
    SupabaseClient? supabaseClient,
  }) async {
    operation.markSyncing();
    debugPrint('[SyncQueueService] Processing: $operation');

    try {
      final payload = json.decode(operation.payload) as Map<String, dynamic>;
      final client = supabaseClient ?? Supabase.instance.client;

      // Handle backwards compatibility for pending queue operations from older app versions
      var tableName = operation.tableName;
      if (tableName == 'trips') {
        tableName = 'driver_trips';
      }

      final result = await _executeOperation(
        client,
        operation,
        tableName,
        payload,
      );

      await result.fold(
        (failure) async {
          debugPrint('[SyncQueueService] Network result failed for ${operation.id}: $failure');
          if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
            // Stop processing the queue immediately on auth errors to prevent hammering
            operation.markFailed('Authentication error: ${failure.message}');
            await operation.save();
            _isProcessing = false;
            _emitStatus();
          } else {
            _handleOperationFailure(operation, failure.message);
          }
        },
        (_) async {
          // Success - remove from queue
          await operation.delete();
          debugPrint('[SyncQueueService] Completed: ${operation.id}');
        },
      );
    } catch (e) {
      debugPrint('[SyncQueueService] Failed (Non-network): ${operation.id}, error: $e');
      _handleOperationFailure(operation, e.toString());
    }
  }

  Future<Result<bool>> _executeOperation(
    SupabaseClient client,
    SyncOperation operation,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    final netClient = CoreNetworkClient(client);

    return netClient.query<bool>(
      () async {
        switch (operation.operationType) {
          case 'create':
            return await _handleUpsert(client, tableName, payload);
          case 'update':
            return await _handleUpdate(client, tableName, payload);
          case 'delete':
            return await _handleDelete(client, tableName, payload);
          case 'upload_document':
            return await _handleUpload(client, tableName, payload);
          default:
            throw Exception('Unknown operation type: ${operation.operationType}');
        }
      },
      operationName: 'sync_${operation.operationType}_$tableName',
    );
  }

  Future<bool> _handleUpsert(
    SupabaseClient client,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    // Use upsert to be idempotent in case of retries
    await client.from(tableName).upsert(payload);
    return true;
  }

  Future<bool> _handleUpdate(
    SupabaseClient client,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    final id = payload['id'] as String?;
    if (id == null) throw Exception('Update requires id in payload');

    // Implement Last-Write-Wins (LWW)
    await client.from(tableName).update(payload).eq('id', id);
    return true;
  }

  Future<bool> _handleDelete(
    SupabaseClient client,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    final id = payload['id'] as String?;
    if (id == null) throw Exception('Delete requires id in payload');
    await client.from(tableName).delete().eq('id', id);
    return true;
  }

  Future<bool> _handleUpload(
    SupabaseClient client,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    // 1. Extract file path and metadata
    final localFilePath = payload['local_file_path'] as String;
    final storagePath = payload['storage_path'] as String;
    final dbData = payload['db_data'] as Map<String, dynamic>;
    final mimeType = payload['mime_type'] as String;

    // 2. Upload to Storage
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw Exception('Local file not found for upload: $localFilePath');
    }

    await client.storage
        .from(tableName == 'documents' ? 'documents' : 'trip_documents')
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    // 3. Insert into Database
    await client.from(tableName).insert(dbData);

    // 4. Cleanup local file (optional, but good practice if it's a temp scan)
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[SyncQueueService] Failed to delete temp file: $e');
    }
    return true;
  }

  void _handleOperationFailure(SyncOperation operation, String errorMessage) {
    if (operation.canRetry) {
      operation.markFailed(errorMessage);
      operation.save();
    } else {
      // Max retries reached, keep in queue as failed for user to see
      operation.markFailed(errorMessage);
      operation.save();
    }
  }

  /// Clear all completed and failed operations
  Future<void> clearCompleted() async {
    final box = _ensureBox;
    final toRemove = box.values
        .where((op) => op.status == 'completed' || op.status == 'failed')
        .map((op) => op.id)
        .toList();

    for (final id in toRemove) {
      await box.delete(id);
    }
    _emitStatus();
  }

  /// Retry all failed operations
  Future<void> retryFailed() async {
    final box = _ensureBox;
    final failed = box.values.where((op) => op.status == 'failed').toList();

    for (final op in failed) {
      op.retryCount = 0;
      op.resetToPending();
    }

    unawaited(processQueue());
  }

  void _emitStatus() {
    if (!connectivityService.isOnline) {
      _statusController.add(SyncStatusInfo.offline());
    } else if (failedCount > 0) {
      _statusController.add(
        SyncStatusInfo.error(failedCount, 'Some operations failed'),
      );
    } else if (pendingCount > 0) {
      _statusController.add(SyncStatusInfo.pending(pendingCount));
    } else {
      _statusController.add(SyncStatusInfo.synced());
    }
  }

  Box<SyncOperation> get _ensureBox {
    final box = _box;
    if (box == null) {
      throw StateError('SyncQueueService.init() must be called before use');
    }
    return box;
  }

  /// Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

/// Global instance for easy access
SyncQueueService get syncQueueService => SyncQueueService.instance;
