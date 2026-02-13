import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/revenue_analytics_provider.dart';
import '../providers/load_analytics_provider.dart';
import '../providers/driver_analytics_provider.dart';
import '../providers/lane_analytics_provider.dart';

import '../widgets/timeframe_selector.dart';
import '../widgets/revenue_trend_chart.dart';
import '../widgets/load_volume_chart.dart';
import '../widgets/top_lanes_list.dart';
import '../widgets/driver_performance_table.dart';
import '../widgets/export_button.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Analytics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TimeframeSelector(),
            const SizedBox(width: 16),
            // We need revenue data for export, so fetch it here or pass it down.
            // Using a consumer widget for the button might be cleaner, but passing data works too.
            // Let's watch it here.
            Consumer(
              builder: (context, ref, child) {
                final revenueAsync = ref.watch(revenueAnalyticsProvider);
                return revenueAsync.when(
                  data: (data) => AnalyticsExportButton(revenueData: data),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
      children: [
        // Row 1: Revenue Trend (Main Chart)
        _ChartContainer(
          title: 'Revenue Trend',
          icon: FluentIcons.money_24_regular,
          height: 300,
          child: Consumer(
            builder: (context, ref, child) {
              final asyncValue = ref.watch(revenueAnalyticsProvider);
              return asyncValue.when(
                data: (data) => RevenueTrendChart(data: data),
                loading: () => const Center(child: ProgressRing()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Row 2: Load Volume & Top Lanes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _ChartContainer(
                title: 'Load Volume',
                icon: FluentIcons.box_24_regular,
                height: 300,
                child: Consumer(
                  builder: (context, ref, child) {
                    final asyncValue = ref.watch(loadAnalyticsProvider);
                    return asyncValue.when(
                      data: (data) => LoadVolumeChart(data: data),
                      loading: () => const Center(child: ProgressRing()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _ChartContainer(
                title: 'Top Lanes',
                icon: FluentIcons.map_24_regular,
                height: 300,
                child: Consumer(
                  builder: (context, ref, child) {
                    final asyncValue = ref.watch(laneAnalyticsProvider);
                    return asyncValue.when(
                      data: (data) => TopLanesList(data: data),
                      loading: () => const Center(child: ProgressRing()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 3: Driver Performance
        _ChartContainer(
          title: 'Driver Performance',
          icon: FluentIcons.people_24_regular,
          height: 400,
          child: Consumer(
            builder: (context, ref, child) {
              final asyncValue = ref.watch(driverAnalyticsProvider);
              return asyncValue.when(
                data: (data) => DriverPerformanceTable(data: data),
                loading: () => const Center(child: ProgressRing()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final double height;

  const _ChartContainer({
    required this.title,
    required this.icon,
    required this.child,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
