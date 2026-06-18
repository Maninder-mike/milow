import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationRepository {
  final DriverDatabase _db;
  final SupabaseClient _supabase;
  Timer? _syncTimer;
  String? _cachedCompanyId;

  LocationRepository(this._db, this._supabase);

  /// Starts a periodic timer to sync local locations to Supabase and prune old logs.
  void startSyncTimer({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncLocations());
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Syncs the latest unsynced location to Supabase and marks all older local records as synced.
  Future<void> syncLocations() async {
    try {
      // 1. Get all unsynced locations sorted by timestamp (newest first)
      final unsynced = await (_db.select(_db.driverLocations)
            ..where((t) => t.isSynced.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
          .get();

      if (unsynced.isEmpty) {
        // Run pruning even if there is nothing to sync
        await pruneOldLocations();
        return;
      }

      // 2. We only sync the single latest location to Supabase because the server table
      // is a 1-row-per-driver table designed for real-time visibility.
      final latestLoc = unsynced.first;
      final driverId = latestLoc.driverId;

      // 3. Ensure user is authenticated
      final user = _supabase.auth.currentUser;
      if (user != null && user.id == driverId) {
        // 4. Prefetch company_id if not cached
        if (_cachedCompanyId == null) {
          final profile = await _supabase
              .from('profiles')
              .select('company_id')
              .eq('id', driverId)
              .maybeSingle();
          if (profile != null) {
            _cachedCompanyId = profile['company_id'] as String?;
          }
        }

        final companyId = _cachedCompanyId;
        if (companyId != null) {
          // 5. Upsert only the latest location using the correct table schema
          await _supabase.from('driver_locations').upsert({
            'driver_id': driverId,
            'company_id': companyId,
            'latitude': latestLoc.latitude,
            'longitude': latestLoc.longitude,
            'speed': latestLoc.speed,
            'heading': latestLoc.heading,
            'updated_at': latestLoc.timestamp.toIso8601String(),
          }, onConflict: 'driver_id');
        }
      }

      // 6. Mark all these retrieved records as synced locally
      final ids = unsynced.map((l) => l.id).toList();
      await (_db.update(_db.driverLocations)..where((t) => t.id.isIn(ids)))
          .write(const DriverLocationsCompanion(isSynced: Value(true)));

      // 7. Prune local location records older than 7 days
      await pruneOldLocations();
    } catch (e) {
      // Log error but don't rethrow to keep timer running
      debugPrint('Error syncing locations: $e');
    }
  }

  /// Deletes local location records older than 7 days to prevent database bloat.
  Future<void> pruneOldLocations() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      await (_db.delete(_db.driverLocations)
            ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
          .go();
    } catch (e) {
      debugPrint('Error pruning locations: $e');
    }
  }
}
