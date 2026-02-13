import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/driver_performance.dart';
import 'analytics_repository_provider.dart';
import 'analytics_timeframe_provider.dart';

part 'driver_analytics_provider.g.dart';

@riverpod
Future<List<DriverPerformance>> driverAnalytics(Ref ref) async {
  final timeframe = ref.watch(analyticsTimeframeProvider);
  final repo = ref.watch(analyticsRepositoryProvider);

  final result = await repo.fetchDriverPerformance(timeframe);

  return result.fold((failure) => throw failure, (data) => data);
}
