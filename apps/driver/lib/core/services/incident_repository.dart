import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class IncidentRepository {
  static const _uuid = Uuid();

  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      client.auth.currentUser?.id;

  /// Watch all incidents for current user (reactive)
  static Stream<List<Incident>> watchIncidents({SupabaseClient? supabaseClient}) {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return Stream.value([]);

    final query = driverDatabase.select(driverDatabase.incidents)
      ..where((i) => i.userId.equals(userId) & i.isDeleted.equals(false))
      ..orderBy([
        (i) => OrderingTerm(expression: i.incidentDate, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((d) => _fromData(d)).toList());
  }

  /// Get all incidents (local-first)
  static Future<Result<List<Incident>>> getIncidents({
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final query = driverDatabase.select(driverDatabase.incidents)
        ..where((i) => i.userId.equals(userId) & i.isDeleted.equals(false))
        ..orderBy([
          (i) => OrderingTerm(expression: i.incidentDate, mode: OrderingMode.desc),
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
      return left(CacheFailure('Failed to load local incidents', stack));
    }
  }

  static final _refreshLock = AsyncMutex();

  static Future<Result<List<Incident>>> _refreshFromServer(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    return _refreshLock.synchronized(() async {
      final client = _getClient(supabaseClient);
      try {
        final response = await client
            .from('incidents')
            .select()
            .eq('user_id', userId)
            .order('incident_date', ascending: false);

        final serverIncidents = (response as List).map((json) => Incident.fromJson(json)).toList();

        final pendingCreateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'incidents' && op.operationType == 'create')
            .map((op) => op.localId)
            .toSet();

        final pendingUpdateIds = syncQueueService.pendingOperations
            .where((op) => op.tableName == 'incidents' && op.operationType == 'update')
            .map((op) => op.localId)
            .toSet();

        var deleteQuery = driverDatabase.delete(driverDatabase.incidents)
          ..where((i) => i.userId.equals(userId));

        final idsToPreserve = {...pendingCreateIds, ...pendingUpdateIds};
        if (idsToPreserve.isNotEmpty) {
          deleteQuery = deleteQuery..where((i) => i.id.isNotIn(idsToPreserve.toList()));
        }
        await deleteQuery.go();

        await driverDatabase.batch((batch) {
          for (final incident in serverIncidents) {
            if (pendingUpdateIds.contains(incident.id)) continue;
            batch.insert(
              driverDatabase.incidents,
              _toCompanion(incident),
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        final dataList = await (driverDatabase.select(driverDatabase.incidents)
              ..where((i) => i.userId.equals(userId) & i.isDeleted.equals(false))
              ..orderBy([
                (i) => OrderingTerm(expression: i.incidentDate, mode: OrderingMode.desc),
              ]))
            .get();
        return right(dataList.map((d) => _fromData(d)).toList());
      } catch (e, stack) {
        return left(UnexpectedFailure('Failed to sync incidents from server', originalError: e, stackTrace: stack));
      }
    });
  }

  /// Create a new incident
  static Future<Result<Incident>> createIncident(
    Incident incident, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final localId = incident.id.isEmpty ? _uuid.v4() : incident.id;
      final localIncident = incident.copyWith(
        id: localId,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await driverDatabase
          .into(driverDatabase.incidents)
          .insert(_toCompanion(localIncident));

      final payload = localIncident.toJson();
      await syncQueueService.enqueue(
        tableName: 'incidents',
        operationType: 'create',
        payload: payload,
        localId: localId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(localIncident);
    } catch (e, stack) {
      return left(CacheFailure('Failed to create incident locally', stack));
    }
  }

  /// Update an incident
  static Future<Result<Incident>> updateIncident(
    Incident incident, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      final updatedIncident = incident.copyWith(updatedAt: DateTime.now());

      await (driverDatabase.update(driverDatabase.incidents)
            ..where((i) => i.id.equals(updatedIncident.id)))
          .write(_toCompanion(updatedIncident));

      final payload = updatedIncident.toJson();
      await syncQueueService.enqueue(
        tableName: 'incidents',
        operationType: 'update',
        payload: payload,
        localId: updatedIncident.id,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(updatedIncident);
    } catch (e, stack) {
      return left(CacheFailure('Failed to update incident locally', stack));
    }
  }

  /// Delete an incident (soft delete)
  static Future<Result<Unit>> deleteIncident(
    String incidentId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return left(const UnauthorizedFailure('User not authenticated'));

    try {
      await (driverDatabase.update(driverDatabase.incidents)
            ..where((i) => i.id.equals(incidentId)))
          .write(const IncidentsCompanion(isDeleted: Value(true)));

      await syncQueueService.enqueue(
        tableName: 'incidents',
        operationType: 'update',
        payload: {
          'id': incidentId,
          'user_id': userId,
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        localId: incidentId,
      );

      unawaited(syncQueueService.processQueue(supabaseClient: client));
      return right(unit);
    } catch (e, stack) {
      return left(CacheFailure('Failed to delete incident locally', stack));
    }
  }

  static Incident _fromData(IncidentData data) {
    return Incident(
      id: data.id,
      userId: data.userId,
      companyId: data.companyId,
      tripId: data.tripId,
      incidentDate: data.incidentDate,
      location: data.location,
      description: data.description,
      policeReportNumber: data.policeReportNumber,
      policeDepartment: data.policeDepartment,
      thirdPartyInfo: jsonDecode(data.thirdPartyInfo) as Map<String, dynamic>,
      photos: (jsonDecode(data.photos) as List).cast<String>(),
      createdAt: data.createdAt ?? DateTime.now(),
      updatedAt: data.updatedAt ?? DateTime.now(),
    );
  }

  static IncidentsCompanion _toCompanion(Incident incident) {
    return IncidentsCompanion(
      id: Value(incident.id),
      userId: Value(incident.userId),
      companyId: Value(incident.companyId),
      tripId: Value(incident.tripId),
      incidentDate: Value(incident.incidentDate),
      location: Value(incident.location),
      description: Value(incident.description),
      policeReportNumber: Value(incident.policeReportNumber),
      policeDepartment: Value(incident.policeDepartment),
      thirdPartyInfo: Value(jsonEncode(incident.thirdPartyInfo)),
      photos: Value(jsonEncode(incident.photos)),
      createdAt: Value(incident.createdAt),
      updatedAt: Value(incident.updatedAt),
      isSynced: const Value(false),
      isDeleted: const Value(false),
    );
  }
}
