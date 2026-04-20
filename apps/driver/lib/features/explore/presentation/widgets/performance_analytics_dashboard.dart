import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
import 'package:milow/features/explore/presentation/widgets/charts/trip_frequency_chart.dart';
import 'package:milow/features/explore/presentation/widgets/charts/fuel_cost_trend_chart.dart';
import 'package:milow/features/explore/presentation/widgets/charts/state_distribution_chart.dart';
import 'package:milow/features/explore/presentation/widgets/charts/route_efficiency_chart.dart';
import 'package:milow/core/constants/design_tokens.dart';

class PerformanceAnalyticsDashboard extends StatelessWidget {
  const PerformanceAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.tokens;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Consumer<ExploreProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide)
              _buildWideLayout(provider, isDark, tokens)
            else
              _buildMobileLayout(provider, isDark, tokens),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout(
    ExploreProvider provider,
    bool isDark,
    DesignTokens tokens,
  ) {
    return Column(
      children: [
        _ChartContainer(
          child: TripFrequencyChart(
            data: provider.monthlyDistanceData,
            isDark: isDark,
            unitSystem: provider.unitSystem,
          ),
        ),
        SizedBox(height: tokens.spacingM),
        _ChartContainer(
          child: StateDistributionChart(
            data: provider.distanceByState,
            isDark: isDark,
          ),
        ),
        SizedBox(height: tokens.spacingM),
        _ChartContainer(
          child: RouteEfficiencyChart(
            data: provider.efficiencyTrend,
            isDark: isDark,
          ),
        ),
        SizedBox(height: tokens.spacingM),
        _ChartContainer(
          child: FuelCostTrendChart(
            data: provider.monthlyFuelData,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    ExploreProvider provider,
    bool isDark,
    DesignTokens tokens,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: tokens.spacingM,
      crossAxisSpacing: tokens.spacingM,
      childAspectRatio: 1.2,
      children: [
        _ChartContainer(
          child: TripFrequencyChart(
            data: provider.monthlyDistanceData,
            isDark: isDark,
            unitSystem: provider.unitSystem,
          ),
        ),
        _ChartContainer(
          child: StateDistributionChart(
            data: provider.distanceByState,
            isDark: isDark,
          ),
        ),
        _ChartContainer(
          child: RouteEfficiencyChart(
            data: provider.efficiencyTrend,
            isDark: isDark,
          ),
        ),
        _ChartContainer(
          child: FuelCostTrendChart(
            data: provider.monthlyFuelData,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final Widget child;

  const _ChartContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassyCard(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingM),
        child: child,
      ),
    );
  }
}
