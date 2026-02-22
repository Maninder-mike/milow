import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationRepository {
  final DriverDatabase _db;
  final SupabaseClient _supabase;
  Timer? _syncTimer;

  LocationRepository(this._db, this._supabase);

  /// Starts a periodic timer to sync local locations to Supabase.
  void startSyncTimer({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncLocations());
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Syncs unsynced locations to Supabase in batches.
  Future<void> syncLocations() async {
    try {
      final unsynced =
          await (_db.select(_db.driverLocations)
                ..where((t) => t.isSynced.equals(false))
                ..limit(100))
              .get();

      if (unsynced.isEmpty) return;

      final payload = unsynced
          .map(
            (l) => {
              'id': l.id,
              'driver_id': l.driverId,
              'latitude': l.latitude,
              'longitude': l.longitude,
              'speed': l.speed,
              'heading': l.heading,
              'accuracy': l.accuracy,
              'timestamp': l.timestamp.toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('driver_locations').upsert(payload);

      // Mark as synced locally
      final ids = unsynced.map((l) => l.id).toList();
      await (_db.update(_db.driverLocations)..where((t) => t.id.isIn(ids)))
          .write(const DriverLocationsCompanion(isSynced: Value(true)));
    } catch (e) {
      // Log error but don't rethrow to keep timer running
      debugPrint('Error syncing locations: $e');
    }
  }
}
