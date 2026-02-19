import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'package:fpdart/fpdart.dart'
    hide State; // Hide State to avoid conflict with Flutter
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';

import 'package:drift/drift.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/trip_service.dart';

/// Repository for trips with offline-first support.
///
/// - Reads from local cache first (instant)
/// - Writes to local cache immediately + queues sync
/// - Background syncs when online
class TripRepository {
  static const _uuid = Uuid();
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static String? _getUserId(SupabaseClient client) =>
      mockUserId ?? client.auth.currentUser?.id;

  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => mockUserId ?? _client.auth.currentUser?.id;
  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Mock user ID for testing
  @visibleForTesting
  static String? mockUserId;

  /// Get all trips for current user (local-first)
  ///
  /// Returns cached data immediately. If [refresh] is true, also
  /// fetches from server in the background.
  static Future<List<Trip>> getTrips({
    bool refresh = true,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return [];

    // Return cached data immediately
    final query = driverDatabase.select(driverDatabase.trips)
      ..where((t) => t.userId.equals(userId));
    final List<TripData> tripDataList = await query.get();
    final List<Trip> cached = tripDataList.map((d) => _fromData(d)).toList();

    if (refresh && connectivityService.isOnline) {
      // Fire-and-forget refresh
      unawaited(_refreshFromServer(userId));
    }

    return cached;
  }

  /// Force refresh from server and update cache
  static Future<List<Trip>> refresh() async {
    final userId = _userId;
    if (userId == null) return [];

    return await _refreshFromServer(userId);
  }

  static Future<List<Trip>> _refreshFromServer(String userId) async {
    try {
      final serverTrips = await TripService.getTrips(
        coalesceKey: 'trips:$userId',
      );

      // Get pending sync operations to prevent overwriting/deleting unsynced data
      final pendingOps = syncQueueService.pendingOperations
          .where((op) => op.tableName == 'trips')
          .toList();

      final pendingCreateIds = pendingOps
          .where((op) => op.operationType == 'create')
          .map((op) => op.localId)
          .toSet();

      final pendingUpdateIds = pendingOps
          .where((op) => op.operationType == 'update')
          .map((op) => op.localId)
          .toSet();

      // Clear existing local cache for this user, BUT preserve pending creates
      final existingData = await (driverDatabase.select(
        driverDatabase.trips,
      )..where((t) => t.userId.equals(userId))).get();
      for (final data in existingData) {
        // id is non-nullable in Drill generated classes, check is redundant

        if (pendingCreateIds.contains(data.id)) {
          continue;
        }
        await (driverDatabase.delete(
          driverDatabase.trips,
        )..where((t) => t.id.equals(data.id))).go();
        // }
      }

      // Update local cache with server data, BUT respect pending updates
      await driverDatabase.batch((batch) {
        for (final trip in serverTrips) {
          if (trip.id != null && pendingUpdateIds.contains(trip.id)) {
            continue;
          }
          batch.insert(
            driverDatabase.trips,
            _toCompanion(trip),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      debugPrint(
        '[TripRepository] Refreshed ${serverTrips.length} trips from server',
      );
      return serverTrips;
    } catch (e) {
      debugPrint('[TripRepository] Failed to refresh: $e');
      // Return cached data on failure
      final List<TripData> dataList = await (driverDatabase.select(
        driverDatabase.trips,
      )..where((t) => t.userId.equals(userId))).get();
      return dataList.map((d) => _fromData(d)).toList();
    }
  }

  /// Get a single trip by ID (local-first)
  static Future<Trip?> getTripById(
    String tripId, {
    SupabaseClient? supabaseClient,
  }) async {
    // Check local cache first
    final query = driverDatabase.select(driverDatabase.trips)
      ..where((t) => t.id.equals(tripId));
    final data = await query.getSingleOrNull();
    if (data != null) return _fromData(data);

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await TripService.getTripById(
        tripId,
        coalesceKey: 'trip:$tripId',
        supabaseClient: supabaseClient,
      );
    }

    return null;
  }

  /// Create a new trip (offline-capable)
  ///
  /// Saves to local cache immediately and queues sync.
  /// Returns the trip with a local ID that will be synced.
  static Future<Trip> createTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Generate local ID if not present
    final localId = trip.id ?? _uuid.v4();
    final localTrip = trip.copyWith(
      id: localId,
      userId: userId,
      createdAt: DateTime.now(),
    );

    // Save to local cache immediately
    await driverDatabase
        .into(driverDatabase.trips)
        .insert(_toCompanion(localTrip));
    debugPrint('[TripRepository] Created locally: $localId');

    // Queue sync operation
    final payload = localTrip.toJson();
    payload['user_id'] = userId;
    payload.remove('id'); // Server will generate its own ID

    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'create',
      payload: payload,
      localId: localId,
    );

    return localTrip;
  }

  /// Update an existing trip (offline-capable)
  static Future<Trip> updateTrip(
    Trip trip, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (trip.id == null) {
      throw Exception('Trip ID is required for update');
    }

    // Update local cache immediately
    final updatedTrip = trip.copyWith(updatedAt: DateTime.now());

    await driverDatabase
        .update(driverDatabase.trips)
        .replace(_toCompanion(updatedTrip));
    debugPrint('[TripRepository] Updated locally: ${trip.id}');

    // Queue sync operation
    final payload = updatedTrip.toJson();
    payload['updated_at'] = DateTime.now().toIso8601String();

    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'update',
      payload: payload,
      localId: trip.id!,
    );

    return updatedTrip;
  }

  /// Delete a trip (offline-capable)
  static Future<void> deleteTrip(
    String tripId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Delete from local cache immediately
    await (driverDatabase.delete(
      driverDatabase.trips,
    )..where((t) => t.id.equals(tripId))).go();
    debugPrint('[TripRepository] Deleted locally: $tripId');

    // Queue sync operation (Soft Delete)
    await syncQueueService.enqueue(
      tableName: 'trips',
      operationType: 'update',
      payload: {
        'id': tripId,
        'user_id': userId,
        'deleted_at': DateTime.now().toIso8601String(),
      },
      localId: tripId,
    );
  }

  /// Search trips (local search if offline, server if online)
  static Future<List<Trip>> searchTrips(
    String query, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return [];

    if (connectivityService.isOnline) {
      try {
        return await TripService.searchTrips(query, supabaseClient: client);
      } catch (_) {
        // Fallback to local search
      }
    }

    // Local search
    final queryLower = '%${query.toLowerCase()}%';
    final List<TripData> tripDataList =
        await (driverDatabase.select(driverDatabase.trips)..where(
              (t) =>
                  t.userId.equals(userId) &
                  (t.tripNumber.like(queryLower) |
                      t.truckNumber.like(queryLower)),
            ))
            .get();
    return tripDataList.map((d) => _fromData(d)).toList();
  }

  static Future<Result<List<TripDocument>>> getSharedDocuments(
    String companyId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return const Left(UnauthorizedFailure());

    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('trip_documents')
          .select('*, trips(trip_number)')
          .eq('company_id', companyId)
          .neq('user_id', userId)
          .order('created_at', ascending: false);
      return response;
    }, operationName: 'getSharedDocuments');

    return result.fold((failure) => Left(failure), (data) {
      try {
        final docs = (data as List)
            .map((doc) => TripDocument.fromJson(doc as Map<String, dynamic>))
            .toList();
        return Right(docs);
      } catch (e) {
        return Left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Download a document to a temporary file
  static Future<Result<File>> downloadDocument(
    TripDocument doc, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    return _getNetworkClient(client).query(() async {
      String? downloadUrl;
      if (doc.url != null && doc.url!.isNotEmpty) {
        downloadUrl = doc.url;
      } else if (doc.filePath.isNotEmpty) {
        downloadUrl = await client.storage
            .from('trip_documents')
            .createSignedUrl(doc.filePath, 60);
      } else {
        throw Exception('No document URL or path available');
      }

      final response = await http.get(Uri.parse(downloadUrl!));
      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName =
          doc.fileName ??
          'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      return tempFile;
    }, operationName: 'downloadDocument');
  }

  /// Resolve trip ID from trip number
  static Future<Result<String?>> resolveTripId(
    String tripNumber, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return const Left(UnauthorizedFailure());

    return _getNetworkClient(client).query(() async {
      final response = await client
          .from('trips')
          .select('id')
          .eq('trip_number', tripNumber)
          .maybeSingle();
      return response?['id'] as String?;
    }, operationName: 'resolveTripId');
  }

  /// Upload a document (offline capable)
  static Future<Result<void>> uploadDocument({
    required File file,
    required TripDocumentType type,
    required String tripNumber, // Used for filename
    required String notes,
    String? tripId,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return const Left(UnauthorizedFailure());

    // Logic:
    // 1. Generate path/filename
    // 2. If Offline -> Queue
    // 3. If Online -> Upload & Insert

    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    // Format: BOL-TR12345-20240401.pdf
    final shortType = type.name.toUpperCase().substring(0, 3);
    final fileName = '$shortType-$tripNumber-$dateStr.pdf';
    final folderId = tripId ?? tripNumber;
    final storagePath = '$userId/$folderId/$fileName';
    const mimeType = 'application/pdf';

    if (!connectivityService.isOnline) {
      // Offline
      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        final pendingDir = Directory('${appDocsDir.path}/pending_uploads');
        if (!await pendingDir.exists()) {
          await pendingDir.create(recursive: true);
        }
        final localFile = File('${pendingDir.path}/$fileName');
        await file.copy(localFile.path);

        final dbData = {
          'trip_id': tripId,
          'user_id': userId,
          'document_type': type.value,
          'file_path': storagePath,
          'file_name': fileName,
          'file_size': await file.length(),
          'mime_type': mimeType,
          'notes': notes,
          'description': notes,
          'object_key': type.name, // Simplified object key logic
        };

        await syncQueueService.enqueue(
          tableName: 'trip_documents',
          operationType: 'upload_document',
          payload: {
            'local_file_path': localFile.path,
            'storage_path': storagePath,
            'db_data': dbData,
            'mime_type': mimeType,
          },
          localId: const Uuid().v4(),
        );
        return const Right(null);
      } catch (e) {
        return Left(CacheFailure(e.toString()));
      }
    }

    // Online
    return _getNetworkClient(client).query(() async {
      await client.storage
          .from('trip_documents')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      await client.from('trip_documents').insert({
        'trip_id': tripId,
        'user_id': userId,
        'document_type': type.value,
        'file_path': storagePath,
        'file_name': fileName,
        'file_size': await file.length(),
        'mime_type': mimeType,
        'notes': notes,
        'description': notes,
        'object_key': type.name,
      });
    }, operationName: 'uploadDocument');
  }

  static Future<Result<List<TripDocument>>> getDocuments(
    String userId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('trip_documents')
          .select('*, trips(trip_number)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return response;
    }, operationName: 'getDocuments');

    return result.fold((failure) => Left(failure), (data) {
      try {
        final docs = (data as List)
            .map((doc) => TripDocument.fromJson(doc as Map<String, dynamic>))
            .toList();
        return Right(docs);
      } catch (e) {
        return Left(ParsingFailure(e.toString()));
      }
    });
  }

  static Future<Result<void>> deleteDocuments(
    List<TripDocument> docs, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    return _getNetworkClient(client).query(() async {
      final filePaths = docs
          .map((d) => d.filePath)
          .where((path) => path.isNotEmpty)
          .toList();
      final idsToDelete = docs.map((d) => d.id).whereType<String>().toList();

      if (filePaths.isNotEmpty) {
        await client.storage.from('trip_documents').remove(filePaths);
      }
      await client.from('trip_documents').delete().inFilter('id', idsToDelete);
    }, operationName: 'deleteDocuments');
  }

  /// Get active trip (trip that is not fully completed)
  /// A trip is active if it has no end_odometer OR has incomplete deliveries
  static Future<Trip?> getActiveTrip({SupabaseClient? supabaseClient}) async {
    final client = _getClient(supabaseClient);
    final userId = _getUserId(client);
    if (userId == null) return null;

    // Check locally first
    final query = driverDatabase.select(driverDatabase.trips)
      ..where((t) => t.userId.equals(userId) & t.endOdometer.isNull())
      ..limit(1);
    final data = await query.getSingleOrNull();
    if (data != null) return _fromData(data);

    // Fallback to server if online
    if (connectivityService.isOnline) {
      return await TripService.getActiveTrip(supabaseClient: client);
    }

    return null;
  }

  /// Clear local cache (for logout)
  static Future<void> clearCache() async {
    await driverDatabase.delete(driverDatabase.trips).go();
    await driverDatabase.delete(driverDatabase.fuelEntries).go();
  }

  static Trip _fromData(TripData data) {
    return Trip(
      id: data.id,
      userId: data.userId,
      vehicleId: data.vehicleId,
      tripNumber: data.tripNumber,
      truckNumber: data.truckNumber,
      trailers: (jsonDecode(data.trailers) as List).cast<String>(),
      tripDate: data.tripDate,
      pickupLocations: (jsonDecode(data.pickupLocations) as List)
          .cast<String>(),
      deliveryLocations: (jsonDecode(data.deliveryLocations) as List)
          .cast<String>(),
      pickupTimes: (jsonDecode(data.pickupTimes) as List)
          .map((e) => e == null ? null : DateTime.parse(e.toString()))
          .toList(),
      deliveryTimes: (jsonDecode(data.deliveryTimes) as List)
          .map((e) => e == null ? null : DateTime.parse(e.toString()))
          .toList(),
      pickupCompleted: (jsonDecode(data.pickupCompleted) as List).cast<bool>(),
      deliveryCompleted: (jsonDecode(data.deliveryCompleted) as List)
          .cast<bool>(),
      pickupDetention: (jsonDecode(data.pickupDetention) as List)
          .map((e) => e == null ? null : Detention.fromJson(e))
          .toList(),
      deliveryDetention: (jsonDecode(data.deliveryDetention) as List)
          .map((e) => e == null ? null : Detention.fromJson(e))
          .toList(),
      startOdometer: data.startOdometer,
      endOdometer: data.endOdometer,
      distanceUnit: data.distanceUnit,
      borderCrossing: data.borderCrossing,
      notes: data.notes,
      isEmptyLeg: data.isEmptyLeg,
      commodity: data.commodity,
      weight: data.weight,
      weightUnit: data.weightUnit,
      pieces: data.pieces,
      referenceNumbers: (jsonDecode(data.referenceNumbers) as List)
          .cast<String>(),
      // lastUpdated is used for sync internal logic, but we map it if needed
    );
  }

  static TripsCompanion _toCompanion(Trip trip) {
    return TripsCompanion(
      id: Value(trip.id!),
      userId: Value(trip.userId),
      vehicleId: Value(trip.vehicleId),
      tripNumber: Value(trip.tripNumber),
      truckNumber: Value(trip.truckNumber),
      trailers: Value(jsonEncode(trip.trailers)),
      tripDate: Value(trip.tripDate),
      pickupLocations: Value(jsonEncode(trip.pickupLocations)),
      deliveryLocations: Value(jsonEncode(trip.deliveryLocations)),
      pickupTimes: Value(
        jsonEncode(trip.pickupTimes.map((e) => e?.toIso8601String()).toList()),
      ),
      deliveryTimes: Value(
        jsonEncode(
          trip.deliveryTimes.map((e) => e?.toIso8601String()).toList(),
        ),
      ),
      pickupCompleted: Value(jsonEncode(trip.pickupCompleted)),
      deliveryCompleted: Value(jsonEncode(trip.deliveryCompleted)),
      pickupDetention: Value(
        jsonEncode(trip.pickupDetention.map((e) => e?.toJson()).toList()),
      ),
      deliveryDetention: Value(
        jsonEncode(trip.deliveryDetention.map((e) => e?.toJson()).toList()),
      ),
      startOdometer: Value(trip.startOdometer),
      endOdometer: Value(trip.endOdometer),
      distanceUnit: Value(trip.distanceUnit),
      borderCrossing: Value(trip.borderCrossing),
      notes: Value(trip.notes),
      isEmptyLeg: Value(trip.isEmptyLeg),
      commodity: Value(trip.commodity),
      weight: Value(trip.weight),
      weightUnit: Value(trip.weightUnit),
      pieces: Value(trip.pieces),
      referenceNumbers: Value(jsonEncode(trip.referenceNumbers)),
      lastUpdated: Value(DateTime.now()),
    );
  }
}
