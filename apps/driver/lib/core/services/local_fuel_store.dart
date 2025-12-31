import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Local Hive store for fuel entries.
///
/// Provides immediate local access to fuel data while syncing
/// happens in the background.
class LocalFuelStore {
  static const String _boxName = 'fuel_entries';

  static Box<String>? _box;

  /// Initialize the store
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('[LocalFuelStore] Initialized, items: ${_box?.length}');
  }

  static Box<String> get _ensureBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalFuelStore.init() must be called before use');
    }
    return box;
  }

  /// Get a fuel entry by ID
  static FuelEntry? get(String id) {
    final jsonStr = _ensureBox.get(id);
    if (jsonStr == null) return null;
    try {
      return FuelEntry.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Get all fuel entries for a user
  static List<FuelEntry> getAllForUser(String userId) {
    final entries = <FuelEntry>[];
    for (final jsonStr in _ensureBox.values) {
      try {
        final entry = FuelEntry.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        if (entry.userId == userId) {
          entries.add(entry);
        }
      } catch (_) {
        // Skip invalid entries
      }
    }
    // Sort by date descending
    entries.sort((a, b) => b.fuelDate.compareTo(a.fuelDate));
    return entries;
  }

  /// Save a fuel entry
  static Future<void> put(FuelEntry entry) async {
    if (entry.id == null) return;
    final jsonStr = json.encode(entry.toJson());
    await _ensureBox.put(entry.id, jsonStr);
  }

  /// Delete a fuel entry
  static Future<void> delete(String id) async {
    await _ensureBox.delete(id);
  }

  /// Clear all entries (for logout)
  static Future<void> clear() async {
    await _ensureBox.clear();
  }

  /// Watch for changes
  static ValueListenable<Box<String>> watchBox() => _ensureBox.listenable();
}
