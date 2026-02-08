import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/supabase_provider.dart';
import 'load_providers.dart';

part 'load_stats_provider.g.dart';

class LoadStats {
  final int todayCount;
  final int activeCount;
  final int completedCount;
  final int delayedCount;

  const LoadStats({
    this.todayCount = 0,
    this.activeCount = 0,
    this.completedCount = 0,
    this.delayedCount = 0,
  });
}

@riverpod
Future<LoadStats> loadStats(Ref ref) async {
  final client = ref.watch(supabaseClientProvider);

  // Refresh on table changes
  ref.watch(loadsChangeSignalProvider);

  // We run these in parallel for performance
  // Note: 'head: true' means we only fetch the count, not the data.
  // CountOption.exact is slower but accurate. CountOption.planned is faster.
  // extra: {'count': 'exact'} is the way in some SDK versions, but
  // currently we use .count(CountOption.exact) if available or just check .count()
  // dependent on SDK version. Supabase Flutter v2 uses count().

  // 1. Today's Pickups
  // We need to define "Today" in UTC or local? Usually relative to user but DB is UTC.
  // For simplicity, we use the client's local day range converted to UTC string for comparison if needed,
  // or just date match if the column is date.
  // Assuming `pickup_date` is a timestamptz.
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
  final endOfDay = DateTime(
    now.year,
    now.month,
    now.day,
    23,
    59,
    59,
  ).toIso8601String();

  final todayFuture = client
      .from('loads')
      .count(CountOption.exact)
      .gte('pickup_date', startOfDay)
      .lte('pickup_date', endOfDay);

  // 2. Active (Assigned or In Transit)
  final activeFuture = client.from('loads').count(CountOption.exact).inFilter(
    'status',
    ['assigned', 'in_transit'],
  );

  // 3. Completed (Delivered)
  final completedFuture = client
      .from('loads')
      .count(CountOption.exact)
      .ilike('status', 'delivered');

  // 4. Delayed
  final delayedFuture = client
      .from('loads')
      .count(CountOption.exact)
      .eq('is_delayed', true);

  final results = await Future.wait([
    todayFuture,
    activeFuture,
    completedFuture,
    delayedFuture,
  ]);

  return LoadStats(
    todayCount: results[0],
    activeCount: results[1],
    completedCount: results[2],
    delayedCount: results[3],
  );
}
