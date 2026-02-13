import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/network_provider.dart';
import '../../data/repositories/analytics_repository.dart';

part 'analytics_repository_provider.g.dart';

@riverpod
AnalyticsRepository analyticsRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  return AnalyticsRepository(client);
}
