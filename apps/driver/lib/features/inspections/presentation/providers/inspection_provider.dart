import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:milow/features/inspections/domain/repositories/i_inspection_repository.dart';
import 'package:milow_core/milow_core.dart';

class InspectionProvider extends ChangeNotifier {
  final IInspectionRepository _repository;

  InspectionProvider(this._repository);

  List<DVIRReport> _inspections = [];
  List<DVIRReport> get inspections => _inspections;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadInspections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.getInspections();
    result.fold(
      (failure) => _error = failure.message,
      (data) => _inspections = data,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveInspection(
    DVIRReport inspection, {
    Uint8List? signatureBytes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.saveInspection(
      inspection,
      signatureBytes: signatureBytes,
    );

    result.fold(
      (failure) => _error = failure.message,
      (_) async => await loadInspections(),
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncInspections() async {
    final result = await _repository.syncPendingInspections();
    result.fold((failure) => debugPrint('Sync failed: ${failure.message}'), (
      count,
    ) async {
      if (count > 0) {
        await loadInspections();
      }
    });
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
