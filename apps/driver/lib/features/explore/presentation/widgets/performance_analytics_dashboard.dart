import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
import 'package:milow/features/explore/presentation/widgets/charts/trip_frequency_chart.dart';
import 'package:milow/features/explore/presentation/widgets/charts/fuel_cost_trend_chart.dart';

class PerformanceAnalyticsDashboard extends StatelessWidget {
  const PerformanceAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ExploreProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassyCard(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TripFrequencyChart(
                      data: provider.monthlyDistanceData,
                      isDark: isDark,
                      unitSystem: provider.unitSystem,
                    ),
                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 32),
                    FuelCostTrendChart(
                      data: provider.monthlyFuelData,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
