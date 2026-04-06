import 'package:flutter/foundation.dart';
import 'package:milow/core/services/location/location_tracking_service.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow_core/milow_core.dart';

class LocationController extends ChangeNotifier {
  final LocationTrackingService _service;
  
  LocationController(this._service);

  bool get isTracking => _service.isTracking;

  /// Update tracking state based on the current load status.
  /// We only track when the load is 'enRoute'.
  void updateTrackingForLoad(Load? load) {
    if (load == null) {
      if (isTracking) {
        AppLogger.info('LocationController: No active load, stopping tracking');
        _service.stopTracking();
        _service.updateActiveStops([]); // Clear geofences
        notifyListeners();
      }
      return;
    }

    final driverId = ProfileService.currentUserId;
    if (driverId == null) return;

    if (load.status == LoadStatus.enRoute || load.status == LoadStatus.atStop) {
      if (!isTracking) {
        AppLogger.info('LocationController: Load ${load.status.name}, starting tracking');
        _service.startTracking(driverId: driverId);
      }
      
      // Sync geofencing stops
      _service.updateActiveStops(load.stops);
      notifyListeners();
    } else {
      if (isTracking) {
        AppLogger.info('LocationController: Load not active (${load.status.name}), stopping tracking');
        _service.stopTracking();
        _service.updateActiveStops([]); // Clear geofences
        notifyListeners();
      }
    }
  }

  /// Explicitly stop tracking (e.g. on logout or app close)
  void stop() {
    if (isTracking) {
      _service.stopTracking();
      notifyListeners();
    }
  }
}
