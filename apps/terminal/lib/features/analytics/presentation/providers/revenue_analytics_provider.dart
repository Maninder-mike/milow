import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/revenue_data_point.dart';
import 'analytics_repository_provider.dart';
import 'analytics_timeframe_provider.dart';

part 'revenue_analytics_provider.g.dart';

@riverpod
Future<List<RevenueDataPoint>> revenueAnalytics(Ref ref) async {
  final timeframe = ref.watch(analyticsTimeframeProvider);
  final repo = ref.watch(analyticsRepositoryProvider);

  final result = await repo.fetchRevenueTrend(timeframe);

  return result.fold((failure) => throw failure, (data) => data);
}
