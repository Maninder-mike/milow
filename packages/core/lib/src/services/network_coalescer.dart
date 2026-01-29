import 'dart:async';

/// Request coalescing utility to deduplicate parallel requests.
///
/// When multiple widgets request the same data simultaneously,
/// this ensures only one actual network request is made.
///
/// Usage:
/// ```dart
/// final profile = await coalescer.coalesce(
///   'profile:$userId',
///   () => fetchProfile(userId),
/// );
/// ```
class NetworkCoalescer {
  final Map<String, Future<dynamic>> _inflightRequests = {};

  /// Coalesce multiple identical requests into a single network call.
  ///
  /// [key] uniquely identifies the request (e.g., 'profile:user-123')
  /// [request] is the actual network operation to perform
  ///
  /// If a request with the same key is already in-flight, the existing
  /// Future is returned. Otherwise, a new request is started.
  Future<T> coalesce<T>(String key, Future<T> Function() request) {
    // Return existing in-flight request if one exists
    if (_inflightRequests.containsKey(key)) {
      return _inflightRequests[key] as Future<T>;
    }

    // Start new request and track it
    final future = request().whenComplete(() {
      _inflightRequests.remove(key);
    });

    _inflightRequests[key] = future;
    return future;
  }

  /// Check if a request with the given key is currently in-flight.
  bool isInflight(String key) => _inflightRequests.containsKey(key);

  /// Get the number of currently in-flight requests.
  int get inflightCount => _inflightRequests.length;

  /// Clear all tracked requests (useful for testing).
  void clear() => _inflightRequests.clear();
}

/// Global singleton instance for easy access.
final networkCoalescer = NetworkCoalescer();
