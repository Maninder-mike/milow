import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/models/border_wait_time.dart';

/// Service to prefetch data during authentication for faster app startup
class DataPrefetchService {
  static DataPrefetchService? _instance;
  static DataPrefetchService get instance {
    _instance ??= DataPrefetchService._();
    return _instance!;
  }

  DataPrefetchService._();

  // Cached data
  List<Trip>? _cachedTrips;
  List<FuelEntry>? _cachedFuelEntries;
  List<BorderWaitTime>? _cachedBorderWaitTimes;
  String? _cachedDistanceUnit;
  String? _cachedVolumeUnit;

  // Prefetch state
  bool _isPrefetching = false;
  bool _prefetchComplete = false;
  Completer<void>? _prefetchCompleter;

  /// Check if prefetch is complete
  bool get isPrefetchComplete => _prefetchComplete;

  /// Get cached trips (may be null if not prefetched)
  List<Trip>? get cachedTrips => _cachedTrips;

  /// Get cached fuel entries (may be null if not prefetched)
  List<FuelEntry>? get cachedFuelEntries => _cachedFuelEntries;

  /// Get cached border wait times (may be null if not prefetched)
  List<BorderWaitTime>? get cachedBorderWaitTimes => _cachedBorderWaitTimes;

  /// Get cached distance unit
  String get cachedDistanceUnit => _cachedDistanceUnit ?? 'mi';

  /// Get cached volume unit
  String get cachedVolumeUnit => _cachedVolumeUnit ?? 'gal';

  /// Start prefetching data in the background
  /// Returns a Future that completes when prefetch is done
  Future<void> startPrefetch() async {
    if (_isPrefetching) {
      // Already prefetching, wait for it to complete
      return _prefetchCompleter?.future;
    }

    if (_prefetchComplete) {
      // Already prefetched
      return;
    }

    _isPrefetching = true;
    _prefetchCompleter = Completer<void>();

    try {
      if (kDebugMode) {
        debugPrint('DataPrefetchService: Starting prefetch...');
      }

      // Fetch all data in parallel for maximum speed
      await Future.wait([
        _prefetchTrips(),
        _prefetchFuelEntries(),
        _prefetchBorderWaitTimes(),
        _prefetchPreferences(),
      ]);

      _prefetchComplete = true;

      if (kDebugMode) {
        debugPrint('DataPrefetchService: Prefetch complete!');
        debugPrint('  - Trips: ${_cachedTrips?.length ?? 0}');
        debugPrint('  - Fuel entries: ${_cachedFuelEntries?.length ?? 0}');
        debugPrint(
          '  - Border wait times: ${_cachedBorderWaitTimes?.length ?? 0}',
        );
      }

      _prefetchCompleter?.complete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataPrefetchService: Prefetch error: $e');
      }
      // Complete even on error so auth can proceed
      _prefetchComplete = true;
      _prefetchCompleter?.complete();
    } finally {
      _isPrefetching = false;
    }
  }

  Future<void> _prefetchTrips() async {
    try {
      _cachedTrips = await TripRepository.getTrips();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataPrefetchService: Failed to prefetch trips: $e');
      }
    }
  }

  Future<void> _prefetchFuelEntries() async {
    try {
      _cachedFuelEntries = await FuelRepository.getFuelEntries();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataPrefetchService: Failed to prefetch fuel entries: $e');
      }
    }
  }

  Future<void> _prefetchBorderWaitTimes() async {
    try {
      // Force refresh border wait times
      await BorderWaitTimeService.fetchAllWaitTimes(forceRefresh: true);
      _cachedBorderWaitTimes =
          await BorderWaitTimeService.getSavedBorderWaitTimes();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'DataPrefetchService: Failed to prefetch border wait times: $e',
        );
      }
    }
  }

  Future<void> _prefetchPreferences() async {
    try {
      _cachedDistanceUnit = await PreferencesService.getDistanceUnit();
      _cachedVolumeUnit = await PreferencesService.getVolumeUnit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataPrefetchService: Failed to prefetch preferences: $e');
      }
    }
  }

  /// Wait for prefetch to complete
  Future<void> waitForPrefetch() async {
    if (_prefetchComplete) return;
    if (_prefetchCompleter != null) {
      await _prefetchCompleter!.future;
    }
  }

  /// Clear all cached data (call on sign out)
  void clearCache() {
    _cachedTrips = null;
    _cachedFuelEntries = null;
    _cachedBorderWaitTimes = null;
    _cachedDistanceUnit = null;
    _cachedVolumeUnit = null;
    _prefetchComplete = false;
    _isPrefetching = false;
    _prefetchCompleter = null;

    if (kDebugMode) {
      debugPrint('DataPrefetchService: Cache cleared');
    }
  }

  /// Invalidate cache (data changed, need to refetch)
  void invalidateCache() {
    _prefetchComplete = false;

    if (kDebugMode) {
      debugPrint('DataPrefetchService: Cache invalidated');
    }
  }
}
