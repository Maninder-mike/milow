import 'dart:async';
import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/load_repository.dart';

class LocationTrackingService {
  final DriverDatabase _db;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  DateTime? _lastPublishedAt;
  Position? _lastPublishedPosition;
  
  // Geofencing state
  List<Stop> _activeStops = [];
  final Set<String> _triggeredArrivals = {}; // Prevent duplicate triggers for the same stop in a session
  
  static const _publishInterval = Duration(seconds: 30);
  static const _minDistance = 50.0; // meters

  LocationTrackingService(this._db);

  bool get isTracking => _isTracking;

  Future<void> startTracking({
    required String driverId,
    Duration interval = const Duration(minutes: 1),
    double distanceFilter = 10,
  }) async {
    if (_isTracking) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isTracking = true;

    // Configure location settings
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _handlePositionUpdate(driverId, position);
          },
        );
  }

  /// Update the list of stops to monitor for geofencing
  void updateActiveStops(List<Stop> stops) {
    _activeStops = stops.where((s) => !s.isCompleted && s.arrivedAt == null).toList();
    // Clean up triggered set if stops are removed or changed
    final stopIds = _activeStops.map((s) => s.id).toSet();
    _triggeredArrivals.retainWhere((id) => stopIds.contains(id));
    
    AppLogger.debug('LocationTrackingService: Monitoring ${_activeStops.length} stops for geofencing');
  }

  Future<void> _handlePositionUpdate(String driverId, Position position) async {
    // 1. Save to local DB (Mandatory for offline history)
    await _saveLocationToLocal(driverId, position);
    
    // 2. Throttled publish to Supabase (Real-time fleet visibility)
    final now = DateTime.now();
    final timeThresholdMet = _lastPublishedAt == null || 
        now.difference(_lastPublishedAt!) > _publishInterval;
    
    double distance = 0;
    if (_lastPublishedPosition != null) {
      distance = Geolocator.distanceBetween(
        _lastPublishedPosition!.latitude,
        _lastPublishedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }
    
    final distanceThresholdMet = _lastPublishedPosition == null || distance > _minDistance;
    
    if (timeThresholdMet || distanceThresholdMet) {
      await _publishToSupabase(driverId, position);
      _lastPublishedAt = now;
      _lastPublishedPosition = position;
    }

    // 3. Geofencing check
    await _checkGeofences(position);
  }

  Future<void> _checkGeofences(Position position) async {
    if (_activeStops.isEmpty) return;

    for (final stop in _activeStops) {
      if (stop.location.latitude == null || stop.location.longitude == null) continue;
      if (_triggeredArrivals.contains(stop.id)) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stop.location.latitude!,
        stop.location.longitude!,
      );

      // Arrival threshold: 500 meters
      if (distance < 500) {
        AppLogger.info('LocationTrackingService: Geofence triggered for Stop ${stop.id} (Distance: ${distance.toStringAsFixed(0)}m)');
        _triggeredArrivals.add(stop.id);
        
        // Auto-update arrival status
        try {
          // We need LoadRepository to perform this update. 
          // Since updateStopArrival is static, we can call it directly.
          await LoadRepository.updateStopArrival(
            stop.id, 
            stop.loadId, 
            DateTime.now(),
          );
          AppLogger.info('LocationTrackingService: Automated arrival recorded for ${stop.location.companyName}');
        } catch (e) {
          AppLogger.error('Failed to auto-update arrival', context: {'stop_id': stop.id}, error: e);
        }
      }
    }
  }

  Future<void> _saveLocationToLocal(String driverId, Position position) async {
    final now = DateTime.now();
    try {
      await _db.customInsert(
        'INSERT INTO driver_locations (id, driver_id, latitude, longitude, speed, heading, accuracy, timestamp, is_synced) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(const Uuid().v4()),
          Variable(driverId),
          Variable(position.latitude),
          Variable(position.longitude),
          Variable(position.speed),
          Variable(position.heading),
          Variable(position.accuracy),
          Variable(now.millisecondsSinceEpoch ~/ 1000),
          const Variable(false),
        ],
      );
    } catch (e) {
      // Local logger used here for detailed native errors if needed, 
      // but AppLogger is preferred for monorepo pattern.
      AppLogger.error('Failed to save local location', error: e);
    }
  }

  Future<void> _publishToSupabase(String driverId, Position position) async {
    try {
      // Get company_id from user's current profile context
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      // We assume company_id is available in the profile or cached. 
      // For this operation, we can use a quick select or rely on the trigger 
      // in the database migration (20260329000004) to handle company-specific RLS if inserted via service_role,
      // but here the driver is inserting their own.
      
      // First, get the company_id if not already known
      final profile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', driverId)
          .maybeSingle();
      
      if (profile == null || profile['company_id'] == null) return;
      final companyId = profile['company_id'] as String;

      await _supabase.from('driver_locations').upsert({
        'driver_id': driverId,
        'company_id': companyId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'driver_id');
      
    } catch (e) {
      // Background logic - don't notify user, just log
      AppLogger.error('Failed to publish to Supabase', error: e);
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }
}
