import 'dart:async';
import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:uuid/uuid.dart';

class LocationTrackingService {
  final DriverDatabase _db;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

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
        throw Exception('Location permissions are denied');
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
            _saveLocation(driverId, position);
          },
        );
  }

  Future<void> _saveLocation(String driverId, Position position) async {
    final now = DateTime.now();
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
        Variable(
          now.millisecondsSinceEpoch ~/ 1000,
        ), // Drift stores Dates as unix timestamps
        const Variable(false),
      ],
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }
}
