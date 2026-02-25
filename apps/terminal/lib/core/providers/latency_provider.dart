import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:terminal/core/providers/supabase_provider.dart';

part 'latency_provider.g.dart';

enum LatencyStatus {
  good,
  fair,
  poor,
  disconnected,
  error;

  bool get isGood => this == LatencyStatus.good;
}

@Riverpod(keepAlive: true)
Stream<int?> latency(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
    final start = DateTime.now();
    try {
      await client.rpc('ping');
      return DateTime.now().difference(start).inMilliseconds;
    } catch (_) {
      return null;
    }
  });
}

@Riverpod(keepAlive: true)
LatencyStatus latencyStatus(Ref ref) {
  final latencyValue = ref.watch(latencyProvider).value;

  if (latencyValue == null) return LatencyStatus.disconnected;
  if (latencyValue < 100) return LatencyStatus.good;
  if (latencyValue < 300) return LatencyStatus.fair;
  return LatencyStatus.poor;
}
