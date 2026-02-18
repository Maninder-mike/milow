import 'package:milow_core/milow_core.dart';
import 'dart:typed_data';
import 'dart:io';

abstract class IInspectionRepository {
  /// Get all inspections
  Future<List<Inspection>> getInspections();

  /// Create or Update an inspection
  Future<void> saveInspection(
    Inspection inspection, {
    Uint8List? signatureBytes,
  });

  /// Sync all pending inspections to Supabase
  /// Returns the number of inspections successfully synced
  Future<int> syncPendingInspections();

  /// Delete an inspection (soft delete if synced, hard delete if local)
  Future<void> deleteInspection(String id);

  Future<void> savePhoto(File file, String defectId);
  Future<List<InspectionPhoto>> getPhotosForDefect(String defectId);
}
