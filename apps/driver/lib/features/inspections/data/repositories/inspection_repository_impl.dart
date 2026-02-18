import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/features/inspections/domain/repositories/i_inspection_repository.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart' as domain;
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class InspectionRepositoryImpl implements IInspectionRepository {
  final DriverDatabase _db;
  final domain.CoreNetworkClient _client;

  InspectionRepositoryImpl(this._db, this._client);

  @override
  Future<List<domain.Inspection>> getInspections() async {
    final query =
        (_db.select(
          _db.driverTruckInspections,
        )..where((t) => t.isDeleted.equals(false))).join([
          leftOuterJoin(
            _db.driverTruckInspectionDefects,
            _db.driverTruckInspectionDefects.inspectionId.equalsExp(
              _db.driverTruckInspections.id,
            ),
          ),
        ]);

    final rows = await query.get();
    final grouped = <String, domain.Inspection>{};

    for (final row in rows) {
      final inspectionData = row.readTable(_db.driverTruckInspections);
      final defectData = row.readTableOrNull(_db.driverTruckInspectionDefects);

      final inspection = grouped.putIfAbsent(
        inspectionData.id,
        () => _mapToDomain(inspectionData, []),
      );

      if (defectData != null) {
        final currentDefects = List<domain.InspectionDefect>.from(
          inspection.defects,
        );
        currentDefects.add(_mapDefectToDomain(defectData));
        grouped[inspection.id] = inspection.copyWith(defects: currentDefects);
      }
    }

    return grouped.values.toList();
  }

  @override
  Future<void> saveInspection(
    domain.Inspection inspection, {
    Uint8List? signatureBytes,
  }) async {
    // 1. Save to Local DB (Offline First)
    var inspectionToSave = inspection;

    // Save signature if provided
    if (signatureBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final signaturePath = '${directory.path}/signatures/${inspection.id}.png';
      final signatureFile = File(signaturePath);

      if (!await signatureFile.parent.exists()) {
        await signatureFile.parent.create(recursive: true);
      }

      await signatureFile.writeAsBytes(signatureBytes);
      inspectionToSave = inspectionToSave.copyWith(
        signaturePath: signaturePath,
      );
    }

    await _db.transaction(() async {
      await _db
          .into(_db.driverTruckInspections)
          .insertOnConflictUpdate(
            DriverTruckInspectionData(
              id: inspection.id,
              driverId: inspection.driverId,
              vehicleId: inspection.vehicleId,
              trailerId: inspection.trailerId,
              type: inspection.type,
              odometer: inspection.odometer,
              notes: inspection.notes,
              location: inspection.location,
              signedAt: inspection.signedAt,
              createdAt: inspection.createdAt,
              updatedAt: DateTime.now(),
              lastUpdated: DateTime.now(),
              isSynced: false,
              isDeleted: false,
            ),
          );

      // Replace defects
      await (_db.delete(
        _db.driverTruckInspectionDefects,
      )..where((t) => t.inspectionId.equals(inspection.id))).go();

      for (final defect in inspection.defects) {
        await _db
            .into(_db.driverTruckInspectionDefects)
            .insert(
              DriverTruckInspectionDefectData(
                id: defect.id,
                inspectionId: inspection.id,
                category: defect.category,
                item: defect.item,
                comment: defect.comment,
                isRepaired: defect.isRepaired,
                createdAt: defect.createdAt,
                updatedAt: DateTime.now(),
                lastUpdated: DateTime.now(),
                isSynced: false,
                isDeleted: false,
              ),
            );
      }
    });

    // 2. Attempt Async Sync to Supabase
    try {
      await _syncToSupabase(inspection);
    } catch (e, stack) {
      domain.AppLogger.error(
        'Failed to sync inspection immediately (queued for background): ${inspection.id}',
        error: e,
        stackTrace: stack,
      );
      // Swallow error so UI doesn't break - it's saved locally
    }
  }

  @override
  Future<int> syncPendingInspections() async {
    final pending = await (_db.select(
      _db.driverTruckInspections,
    )..where((t) => t.isSynced.equals(false))).get();

    int syncedCount = 0;

    for (final inspectionData in pending) {
      // We need to fetch defects for this inspection to sync them too
      final defectsQuery = _db.select(_db.driverTruckInspectionDefects)
        ..where((t) => t.inspectionId.equals(inspectionData.id));
      final defectsData = await defectsQuery.get();

      final defects = defectsData.map(_mapDefectToDomain).toList();
      final inspection = _mapToDomain(inspectionData, defects);

      try {
        await _syncToSupabase(inspection);
        syncedCount++;
      } catch (e) {
        domain.AppLogger.warning(
          'Background sync failed for ${inspection.id}: $e',
        );
        // Continue to next item
      }
    }
    return syncedCount;
  }

  Future<void> _syncToSupabase(domain.Inspection inspection) async {
    String? signatureUrl = inspection.signatureUrl;

    // Upload signature if needed
    if (signatureUrl == null && inspection.signaturePath != null) {
      final file = File(inspection.signaturePath!);
      if (await file.exists()) {
        try {
          final fileName = '${inspection.id}_signature.png';
          final storagePath = 'signatures/$fileName';

          // Check if file already exists or just overwrite? upsert is better but storage.upload usually fails if exists
          // We'll try upload, if it fails maybe it exists?
          // Actually, simply using upload with upsert: true if available, or just standard upload.
          // Supabase Flutter SDK upload takes fileOptions.

          await _client.supabase.storage
              .from('inspection_photos')
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );

          signatureUrl = _client.supabase.storage
              .from('inspection_photos')
              .getPublicUrl(storagePath);

          // Update local DB with the new signatureUrl
          await (_db.update(
            _db.driverTruckInspections,
          )..where((t) => t.id.equals(inspection.id))).write(
            DriverTruckInspectionsCompanion(
              signatureUrl: Value(signatureUrl),
              lastUpdated: Value(DateTime.now()),
            ),
          );
        } catch (e) {
          domain.AppLogger.warning(
            'Failed to upload signature for ${inspection.id}: $e',
          );
          // Continue sync without signature URL for now
        }
      }
    }

    await _client.query(() async {
      // Insert Inspection
      await _client.supabase.from('driver_truck_inspections').upsert({
        'id': inspection.id,
        'driver_id': inspection.driverId,
        'vehicle_id': inspection.vehicleId,
        'trailer_id': inspection.trailerId,
        'type': inspection.type,
        'odometer': inspection.odometer,
        'notes': inspection.notes,
        'location': inspection.location,
        'signed_at': inspection.signedAt.toIso8601String(),
        'created_at': inspection.createdAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'signature_url': signatureUrl,
      });

      // Insert Defects (if any)
      if (inspection.defects.isNotEmpty) {
        // Delete existing for simplicity in this MVP sync
        await _client.supabase
            .from('driver_truck_inspection_defects')
            .delete()
            .eq('inspection_id', inspection.id);

        final defectsJson = inspection.defects
            .map(
              (d) => {
                'id': d.id,
                'inspection_id': inspection.id,
                'category': d.category,
                'item': d.item,
                'comment': d.comment,
                'is_repaired': d.isRepaired,
                'created_at': d.createdAt?.toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();

        await _client.supabase
            .from('driver_truck_inspection_defects')
            .upsert(defectsJson);
      }
      return true;
    }, operationName: 'sync_inspection');

    // Mark as Synced locally if successful
    await (_db.update(_db.driverTruckInspections)
          ..where((t) => t.id.equals(inspection.id)))
        .write(const DriverTruckInspectionsCompanion(isSynced: Value(true)));

    // Mark defects as synced
    await (_db.update(
      _db.driverTruckInspectionDefects,
    )..where((t) => t.inspectionId.equals(inspection.id))).write(
      const DriverTruckInspectionDefectsCompanion(isSynced: Value(true)),
    );

    domain.AppLogger.info('Inspection synced successfully: ${inspection.id}');
  }

  @override
  Future<void> deleteInspection(String id) async {
    // 1. Check if synced
    final inspection = await (_db.select(
      _db.driverTruckInspections,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (inspection == null) return;

    if (inspection.isSynced) {
      // 2a. Soft Delete locally
      await (_db.update(
        _db.driverTruckInspections,
      )..where((t) => t.id.equals(id))).write(
        const DriverTruckInspectionsCompanion(
          isDeleted: Value(true),
          isSynced: Value(false), // Needs sync to propagate delete
          lastUpdated:
              Value.absent(), // datetime will be auto-updated by drift or manually if needed?
          // Actually, let's explicit update updatedAt so sync picks it up
        ),
      );

      // Update updatedAt manually if needed by your schema/logic, but usually drift copies don't auto-update unless defined.
      // Let's rely on the sync logic to pick up `isSynced: false`.

      // 2b. Attempt Sync immediately
      try {
        await _syncDeletionToSupabase(id);
      } catch (e) {
        domain.AppLogger.warning('Failed to sync deletion for $id: $e');
      }
    } else {
      // 2b. Hard Delete locally if never synced
      // Transaction to delete defects too
      await _db.transaction(() async {
        await (_db.delete(
          _db.driverTruckInspectionDefects,
        )..where((t) => t.inspectionId.equals(id))).go();
        await (_db.delete(
          _db.driverTruckInspections,
        )..where((t) => t.id.equals(id))).go();
      });
    }
  }

  Future<void> _syncDeletionToSupabase(String id) async {
    // Soft delete in Supabase by setting is_deleted = true
    await _client.query(() async {
      await _client.supabase
          .from('driver_truck_inspections')
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    }, operationName: 'delete_inspection');

    // 4. Delete locally
    await (_db.delete(
      _db.driverTruckInspections,
    )..where((t) => t.id.equals(id))).go();

    domain.AppLogger.info('Inspection deleted: $id');
  }

  @override
  Future<void> savePhoto(File file, String defectId) async {
    final fileName = '${const Uuid().v4()}${path.extension(file.path)}';

    // Save locally
    final appDir = await getApplicationDocumentsDirectory();
    final localDir = Directory('${appDir.path}/inspection_photos');
    await localDir.create(recursive: true);
    final localPath = '${localDir.path}/$fileName';
    await file.copy(localPath);

    // Save metadata to DB
    final photoId = const Uuid().v4();
    await _db
        .into(_db.inspectionDefectPhotos)
        .insert(
          InspectionDefectPhotoData(
            id: photoId,
            defectId: defectId,
            localPath: localPath,
            remoteUrl: null, // Will be updated after sync
            createdAt: DateTime.now(),
          ),
        );

    // Attempt upload immediately (fire and forget or background sync)
    unawaited(_uploadPhoto(file, fileName, photoId));
  }

  Future<void> _uploadPhoto(File file, String fileName, String photoId) async {
    if (!await _client.hasConnection) return;

    try {
      final storagePath = 'defects/$fileName';
      await _client.supabase.storage
          .from('inspection_photos')
          .upload(storagePath, file);
      final publicUrl = _client.supabase.storage
          .from('inspection_photos')
          .getPublicUrl(storagePath);

      // Update DB with remote URL
      await (_db.update(
        _db.inspectionDefectPhotos,
      )..where((t) => t.id.equals(photoId))).write(
        InspectionDefectPhotoData(
          id: photoId,
          defectId: '', // Drift ignores this in update
          localPath: '', // Drift ignores this in update
          remoteUrl: publicUrl,
          createdAt: DateTime.now(), // Drift ignores this in update
        ),
      );
    } catch (e) {
      domain.AppLogger.error('Failed to upload photo', error: e);
    }
  }

  @override
  Future<List<domain.InspectionPhoto>> getPhotosForDefect(
    String defectId,
  ) async {
    final query = _db.select(_db.inspectionDefectPhotos)
      ..where((t) => t.defectId.equals(defectId));

    final results = await query.get();

    return results.map((data) {
      return domain.InspectionPhoto(
        id: data.id,
        defectId: data.defectId,
        localPath: data.localPath,
        remoteUrl: data.remoteUrl,
        createdAt: data.createdAt,
      );
    }).toList();
  }

  domain.Inspection _mapToDomain(
    DriverTruckInspectionData data,
    List<domain.InspectionDefect> defects,
  ) {
    return domain.Inspection(
      id: data.id,
      driverId: data.driverId,
      vehicleId: data.vehicleId,
      trailerId: data.trailerId,
      type: data.type,
      odometer: data.odometer,
      notes: data.notes,
      location: data.location,
      signedAt: data.signedAt,
      signaturePath: data.signaturePath,
      signatureUrl: data.signatureUrl,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      defects: defects,
      isSynced: data.isSynced,
    );
  }

  domain.InspectionDefect _mapDefectToDomain(
    DriverTruckInspectionDefectData data,
  ) {
    return domain.InspectionDefect(
      id: data.id,
      inspectionId: data.inspectionId,
      category: data.category,
      item: data.item,
      comment: data.comment,
      isRepaired: data.isRepaired,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }
}
