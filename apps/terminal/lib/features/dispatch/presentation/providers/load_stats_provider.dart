import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:milow_core/milow_core.dart';
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
  // Refresh on table changes
  ref.watch(loadsChangeSignalProvider);

  final repository = ref.watch(loadRepositoryProvider);
  final result = await repository.fetchLoadStats();

  return result.fold(
    (failure) {
      AppLogger.error('Failed to fetch load stats: ${failure.message}');
      throw failure;
    },
    (stats) => LoadStats(
      todayCount: stats['today'] ?? 0,
      activeCount: stats['active'] ?? 0,
      completedCount: stats['completed'] ?? 0,
      delayedCount: stats['delayed'] ?? 0,
    ),
  );
}
