import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity.
///
/// Provides a stream of connectivity changes and methods to check
/// current online status.
class ConnectivityService {
  static ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Allow subclassing for testing
  @visibleForTesting
  ConnectivityService.testing();

  /// Allow overriding the instance for tests
  @visibleForTesting
  static set instance(ConnectivityService mock) => _instance = mock;

  static ConnectivityService get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  /// Stream of connectivity changes (true = online, false = offline)
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize the connectivity listener
  Future<void> init() async {
    // Check initial state
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
    debugPrint('[ConnectivityService] Initialized, online: $_isOnline');
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Consider online if any connection type is available (except none)
    _isOnline =
        results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      debugPrint('[ConnectivityService] Status changed: $_isOnline');
      _controller.add(_isOnline);
    }
  }

  /// Check connectivity and return online status
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _isOnline;
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Global instance for easy access
ConnectivityService get connectivityService => ConnectivityService.instance;
