import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/analytics_timeframe.dart';

part 'analytics_timeframe_provider.g.dart';

@riverpod
class AnalyticsTimeframeNotifier extends _$AnalyticsTimeframeNotifier {
  @override
  AnalyticsTimeframe build() {
    return AnalyticsTimeframe.month;
  }

  void setTimeframe(AnalyticsTimeframe timeframe) {
    state = timeframe;
  }
}
