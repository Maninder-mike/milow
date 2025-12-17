import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider that listens to connectivity changes.
/// Returns the current list of [ConnectivityResult]s.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider that returns true if the device is connected to the internet.
/// Note: This only checks if there is a network interface, not actual internet access.
final isConnectedProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);

  return connectivityAsync.when(
    data: (results) {
      // If any result is not none, we are connected to some network.
      final _isConnected = !results.contains(ConnectivityResult.none);
      return _isConnected;
    },
    loading: () => true, // Assume connected while loading
    error: (_, __) => false, // Assume connected on error
  );
});
