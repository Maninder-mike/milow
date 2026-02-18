import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:milow/features/inspections/domain/repositories/i_inspection_repository.dart';
import 'package:milow_core/milow_core.dart';

class InspectionProvider extends ChangeNotifier {
  final IInspectionRepository _repository;

  InspectionProvider(this._repository);

  List<Inspection> _inspections = [];
  List<Inspection> get inspections => _inspections;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadInspections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _inspections = await _repository.getInspections();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveInspection(
    Inspection inspection, {
    Uint8List? signatureBytes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.saveInspection(
        inspection,
        signatureBytes: signatureBytes,
      );
      await loadInspections(); // Refresh list
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncInspections() async {
    // Don't set global loading state to avoid blocking UI,
    // but we could have a separate `isSyncing` flag if needed.
    try {
      final count = await _repository.syncPendingInspections();
      if (count > 0) {
        await loadInspections(); // Refresh to show updated sync status if UI shows it
        // Optionally show a toast/notification
      }
    } catch (e) {
      // Log error but don't disrupt user
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> deleteInspection(String id) async {
    _isLoading =
        true; // Optional: maybe simpler to not show full screen loader for delete
    notifyListeners();

    try {
      await _repository.deleteInspection(id);
      await loadInspections();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> savePhoto(File file, String defectId) async {
    await _repository.savePhoto(file, defectId);
    notifyListeners();
  }
}
