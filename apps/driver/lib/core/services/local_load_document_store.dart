import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Local Hive store for load documents.
///
/// Caches documents fetched from Supabase and stores pending uploads for offline-first capabilities.
class LocalLoadDocumentStore {
  static const String _boxName = 'load_documents';
  static Box<String>? _box;

  /// Initialize the store
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('[LocalLoadDocumentStore] Initialized, items: ${_box?.length}');
  }

  static Box<String> get _ensureBox {
    if (_box == null) {
      throw StateError('LocalLoadDocumentStore.init() must be called before use');
    }
    return _box!;
  }

  /// Get all documents for a load (cached)
  static List<LoadDocument> getForLoad(String loadId) {
    final docs = <LoadDocument>[];
    for (final jsonStr in _ensureBox.values) {
      try {
        final doc = LoadDocument.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        if (doc.loadId == loadId) {
          docs.add(doc);
        }
      } catch (e) {
        debugPrint('[LocalLoadDocumentStore] Error parsing doc: $e');
      }
    }
    return docs;
  }

  /// Save multiple documents (usually from a sync/fetch)
  static Future<void> putAll(List<LoadDocument> documents) async {
    final Map<String, String> data = {};
    for (final doc in documents) {
      if (doc.id != null) {
        // Check if we already have this document locally in a pending/failed state
        final existingStr = _ensureBox.get(doc.id);
        if (existingStr != null) {
           try {
            final existingDoc = LoadDocument.fromJson(
              json.decode(existingStr) as Map<String, dynamic>,
            );
            if (existingDoc.status == DocumentStatus.pendingUpload ||
                existingDoc.status == DocumentStatus.uploadFailed) {
              // Skip overwriting local pending/failed documents with server data
              continue;
            }
          } catch (e) {
            debugPrint('[LocalLoadDocumentStore] Error parsing existing doc: $e');
          }
        }
        data[doc.id!] = json.encode(doc.toJson());
      }
    }
    if (data.isNotEmpty) {
      await _ensureBox.putAll(data);
    }
  }

  /// Save a single document
  static Future<void> put(LoadDocument document) async {
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
