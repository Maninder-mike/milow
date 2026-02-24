import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

/// Stream provider that listens to connectivity changes.
/// Returns the current list of [ConnectivityResult]s.
@Riverpod(keepAlive: true)
Stream<List<ConnectivityResult>> connectivity(Ref ref) {
  return Connectivity().onConnectivityChanged;
}

/// Provider that returns true if the device is connected to the internet.
/// Note: This only checks if there is a network interface, not actual internet access.
      // If any result is not none, we are connected to some network.
      final isConnected = !results.contains(ConnectivityResult.none);
      return isConnected;
    },
    loading: () => true, // Assume connected while loading
    error: (error, stack) => false, // Assume connected on error
  );
});
