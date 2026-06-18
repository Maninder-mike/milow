import 'dart:async';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class QuickNoteRepository {
  static const _uuid = Uuid();

  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      client.auth.currentUser?.id;

  /// Watch all quick notes for current user (reactive)
  static Stream<List<QuickNote>> watchQuickNotes({SupabaseClient? supabaseClient}) {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return Stream.value([]);

    final query = driverDatabase.select(driverDatabase.quickNotes)
      ..where((n) => n.userId.equals(userId) & n.isDeleted.equals(false))
      ..orderBy([
        (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((d) => _fromData(d)).toList());
  }

  /// Get all quick notes (local-first)
  static Future<Result<List<QuickNote>>> getQuickNotes({
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final query = driverDatabase.select(driverDatabase.quickNotes)
        ..where((n) => n.userId.equals(userId) & n.isDeleted.equals(false))
        ..orderBy([
          (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
        ]);
      final dataList = await query.get();
      final cached = dataList.map((d) => _fromData(d)).toList();

      if (refresh && connectivityService.isOnline) {
        if (cached.isEmpty) {
          return await _refreshFromServer(userId, supabaseClient: client);
        }
        unawaited(_refreshFromServer(userId, supabaseClient: client));
      }

      return right(cached);
    } catch (e, stack) {
      return left(CacheFailure('Failed to load local quick notes', stack));
    }
  }

  static final _refreshLock = AsyncMutex();

  static Future<Result<List<QuickNote>>> _refreshFromServer(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _refreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      try {
        final response = await client
            .from('quick_notes')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final serverNotes = (response as List).map((json) => QuickNote.fromJson(json)).toList();

        // Get pending operations to avoid overwriting/deleting unsynced data
        final pendingCreateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'quick_notes' && op.operationType == 'create')
            .map((op) => op.localId)
            .toSet();

        final pendingUpdateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'quick_notes' && op.operationType == 'update')
            .map((op) => op.localId)
            .toSet();

        // Clear local cache for this user, except pending
        var deleteQuery = driverDatabase.delete(driverDatabase.quickNotes)
          ..where((n) => n.userId.equals(userId));

        final idsToPreserve = {...pendingCreateIds, ...pendingUpdateIds};
        if (idsToPreserve.isNotEmpty) {
          deleteQuery = deleteQuery..where((n) => n.id.isNotIn(idsToPreserve.toList()));
        }
        await deleteQuery.go();

        // Update local cache
        await driverDatabase.batch((batch) {
          for (final note in serverNotes) {
            if (pendingUpdateIds.contains(note.id)) continue;
            batch.insert(
              driverDatabase.quickNotes,
              _toCompanion(note),
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        final dataList = await (driverDatabase.select(driverDatabase.quickNotes)
              ..where((n) => n.userId.equals(userId) & n.isDeleted.equals(false))
              ..orderBy([
                (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
              ]))
            .get();
        return right(dataList.map((d) => _fromData(d)).toList());
      } catch (e, stack) {
        return left(UnexpectedFailure('Failed to sync quick notes from server', originalError: e, stackTrace: stack));
      }
    });
  }

  /// Create a new quick note
  static Future<Result<QuickNote>> createQuickNote(
    QuickNote note, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final localId = note.id.isEmpty ? _uuid.v4() : note.id;
      final localNote = note.copyWith(
        id: localId,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await driverDatabase
          .into(driverDatabase.quickNotes)
          .insert(_toCompanion(localNote));

      final payload = localNote.toJson();
      await syncQueueService.enqueue(
        tableName: 'quick_notes',
        operationType: 'create',
        payload: payload,
        localId: localId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(localNote);
    } catch (e, stack) {
      return left(CacheFailure('Failed to create quick note locally', stack));
    }
  }

  /// Update a quick note
  static Future<Result<QuickNote>> updateQuickNote(
    QuickNote note, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final updatedNote = note.copyWith(updatedAt: DateTime.now());

      await (driverDatabase.update(driverDatabase.quickNotes)
            ..where((n) => n.id.equals(updatedNote.id)))
          .write(_toCompanion(updatedNote));

      final payload = updatedNote.toJson();
      await syncQueueService.enqueue(
        tableName: 'quick_notes',
        operationType: 'update',
        payload: payload,
        localId: updatedNote.id,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(updatedNote);
    } catch (e, stack) {
      return left(CacheFailure('Failed to update quick note locally', stack));
    }
  }

  /// Delete a quick note (soft delete)
  static Future<Result<Unit>> deleteQuickNote(
    String noteId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      // Mark as deleted locally
      await (driverDatabase.update(driverDatabase.quickNotes)
            ..where((n) => n.id.equals(noteId)))
          .write(const QuickNotesCompanion(isDeleted: Value(true)));

      // Queue sync operation
      await syncQueueService.enqueue(
        tableName: 'quick_notes',
        operationType: 'update',
        payload: {
          'id': noteId,
          'user_id': userId,
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        localId: noteId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(unit);
    } catch (e, stack) {
      return left(CacheFailure('Failed to delete quick note locally', stack));
    }
  }

  static QuickNote _fromData(QuickNoteData data) {
    return QuickNote(
      id: data.id,
      userId: data.userId,
      tripId: data.tripId,
      title: data.title,
      content: data.content,
      createdAt: data.createdAt ?? DateTime.now(),
      updatedAt: data.updatedAt ?? DateTime.now(),
    );
  }

  static QuickNotesCompanion _toCompanion(QuickNote note) {
    return QuickNotesCompanion(
      id: Value(note.id),
      userId: Value(note.userId ?? ''),
      tripId: Value(note.tripId),
      title: Value(note.title),
      content: Value(note.content),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      isSynced: const Value(false),
      isDeleted: const Value(false),
    );
  }
}
