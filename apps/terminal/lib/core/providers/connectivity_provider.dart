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
@riverpod
bool isConnected(Ref ref) {
  final connectivityResult = ref.watch(connectivityProvider);

  return connectivityResult.when(
    data: (results) {
      if (results.isEmpty) return false;
      return !results.contains(ConnectivityResult.none);
    },
    loading: () => true, // Assume connected while loading
    error: (error, stackTrace) => false,
  );
}
