import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Local Hive store for trip documents.
///
/// Caches documents fetched from Supabase and stores pending uploads.
class LocalDocumentStore {
  static const String _boxName = 'trip_documents';
  static Box<String>? _box;

  /// Initialize the store
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('[LocalDocumentStore] Initialized, items: ${_box?.length}');
  }

  static Box<String> get _ensureBox {
    if (_box == null) {
      throw StateError('LocalDocumentStore.init() must be called before use');
    }
    return _box!;
  }

  /// Get all documents for a user (cached)
  static List<TripDocument> getAllForUser(String userId) {
    final docs = <TripDocument>[];
    for (final jsonStr in _ensureBox.values) {
      try {
        final doc = TripDocument.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        if (doc.userId == userId) {
          docs.add(doc);
        }
      } catch (e) {
        debugPrint('[LocalDocumentStore] Error parsing doc: $e');
      }
    }
    return docs;
  }

  /// Save multiple documents (usually from a sync/fetch)
  static Future<void> putAll(List<TripDocument> documents) async {
    // Note: We might want to be careful not to overwrite "Pending" local docs
    // if we implement a local-only indicator. For now, full sync.
    final Map<String, String> data = {};
    for (final doc in documents) {
      if (doc.id != null) {
        data[doc.id!] = json.encode(doc.toJson());
      }
    }
    if (data.isNotEmpty) {
      await _ensureBox.putAll(data);
    }
  }

  /// Save a single document
  static Future<void> put(TripDocument document) async {
    if (document.id == null) return;
    await _ensureBox.put(document.id!, json.encode(document.toJson()));
  }

  /// Delete a document
  static Future<void> delete(String id) async {
    await _ensureBox.delete(id);
  }

  /// Clear all documents
  static Future<void> clear() async {
    await _ensureBox.clear();
  }

  /// Watch box for changes
  static ValueListenable<Box<String>> watchBox() => _ensureBox.listenable();
}
