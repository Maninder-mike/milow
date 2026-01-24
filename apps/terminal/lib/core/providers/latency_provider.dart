import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that emits the network latency (RTT) in milliseconds.
/// Pings a reliable server (Google) every 30 seconds.
/// Returns null if the ping fails or times out.
final latencyProvider = StreamProvider<int?>((ref) {
  // Config
  const pingUrl = 'https://www.google.com';
  const interval = Duration(seconds: 30);
  const timeout = Duration(seconds: 5);

  // Initial ping
  final controller = StreamController<int?>();

  Future<void> ping() async {
    final stopwatch = Stopwatch()..start();
    try {
      await http.head(Uri.parse(pingUrl)).timeout(timeout);
      stopwatch.stop();
      controller.add(stopwatch.elapsedMilliseconds);
    } catch (e) {
      // On error (timeout, no net, etc), emit null to indicate issue
      controller.add(null);
    }
  }

  // Run immediately
  ping();

  // Run periodically
  final timer = Timer.periodic(interval, (_) => ping());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Returns a color based on latency value.
/// Green: < 100ms
/// Orange: 100ms - 300ms
/// Red: > 300ms (or null/error)
final latencyStatusProvider = Provider.family<LatencyStatus, int?>((
  ref,
  latency,
) {
  if (latency == null) return LatencyStatus.error;
  if (latency < 100) return LatencyStatus.good;
  if (latency < 300) return LatencyStatus.fair;
  return LatencyStatus.poor;
});

enum LatencyStatus {
  good,
  fair,
  poor,
  error;

  bool get isGood => this == LatencyStatus.good;
}
