import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/lane_analytics.dart';
import 'analytics_repository_provider.dart';
import 'analytics_timeframe_provider.dart';

part 'lane_analytics_provider.g.dart';

@riverpod
Future<List<LaneAnalytics>> laneAnalytics(Ref ref) async {
  final timeframe = ref.watch(analyticsTimeframeProvider);
  final repo = ref.watch(analyticsRepositoryProvider);

  final result = await repo.fetchLaneAnalytics(timeframe);

  return result.fold((failure) => throw failure, (data) => data);
}
