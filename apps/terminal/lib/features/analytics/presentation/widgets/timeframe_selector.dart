import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/analytics_timeframe.dart';
import '../providers/analytics_timeframe_provider.dart';

class TimeframeSelector extends ConsumerWidget {
  const TimeframeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTimeframe = ref.watch(analyticsTimeframeProvider);

    return Container(
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AnalyticsTimeframe.values
            .where((t) => t != AnalyticsTimeframe.custom)
            .map((timeframe) {
              final isSelected = timeframe == selectedTimeframe;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(analyticsTimeframeProvider.notifier)
                        .setTimeframe(timeframe);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FluentTheme.of(
                              context,
                            ).accentColor.withValues(alpha: 0.1)
                          : null,
                      border: isSelected
                          ? Border(
                              bottom: BorderSide(
                                color: FluentTheme.of(context).accentColor,
                                width: 2,
                              ),
                            )
                          : null,
                    ),
                    child: Text(
                      _getLabel(timeframe),
                      style: TextStyle(
                        color: isSelected
                            ? FluentTheme.of(context).accentColor
                            : FluentTheme.of(
                                context,
                              ).resources.textFillColorSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }

  String _getLabel(AnalyticsTimeframe timeframe) {
    switch (timeframe) {
      case AnalyticsTimeframe.week:
        return 'Week';
      case AnalyticsTimeframe.month:
        return 'Month';
      case AnalyticsTimeframe.quarter:
        return 'Quarter';
      case AnalyticsTimeframe.year:
        return 'Year';
      default:
        return '';
    }
  }
}
