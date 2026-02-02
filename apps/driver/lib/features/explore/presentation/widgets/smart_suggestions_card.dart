import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import '../utils/explore_utils.dart';

class SmartSuggestionsCard extends StatelessWidget {
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;

  const SmartSuggestionsCard({
    required this.trips,
    required this.fuelEntries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final suggestions = _generateSuggestions(context);

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMART INSIGHTS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Data-driven performance analysis',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ...suggestions,
        ],
      ),
    );
  }

  List<Widget> _generateSuggestions(BuildContext context) {
    final list = <Widget>[];
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // 1. Data Analysis Constants
    double totalMiles = 0;
    double totalFuelCost = 0;
    double totalFuelQty = 0;
    final stateCounts = <String, int>{};

    for (var t in trips) {
      totalMiles += t.totalDistance ?? 0;
      final code = ExploreUtils.extractStateCode(
        t.pickupLocations.firstOrNull ?? '',
      );
      if (code != null) {
        stateCounts[code] = (stateCounts[code] ?? 0) + 1;
      }
    }

    for (var f in fuelEntries) {
      totalFuelCost += f.totalCost;
      totalFuelQty += f.fuelQuantity;
    }

    // 2. Weekly Progress vs Goal
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    double weekMiles = 0;
    for (var t in trips) {
      if (t.tripDate.isAfter(startOfWeek)) {
        weekMiles += t.totalDistance ?? 0;
      }
    }

    list.add(
      _buildInsightTile(
        context,
        icon: Icons.speed_rounded,
        title: 'Weekly Performance',
        value: '${weekMiles.round()} mi',
        description:
            'You are at ${(weekMiles / 25).toStringAsFixed(0)}% of your weekly target.',
        color: weekMiles > 1000 ? Colors.green : colorScheme.primary,
        onTap: () => context.go('/dashboard'),
      ),
    );

    // 3. Fuel Efficiency (MPG)
    if (totalMiles > 0 && totalFuelQty > 0) {
      final mpg = totalMiles / totalFuelQty;
      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.local_gas_station_rounded,
          title: 'Fuel Efficiency',
          value: '${mpg.toStringAsFixed(1)} MPG',
          description: mpg < 6.0
              ? 'Efficiency is low. Check tire pressure.'
              : 'Great job! You are driving efficiently.',
          color: mpg < 6.0 ? Colors.orange : colorScheme.secondary,
        ),
      );
    }

    // 4. Cost Per Mile (CPM)
    if (totalMiles > 0 && totalFuelCost > 0) {
      final cpm = totalFuelCost / totalMiles;
      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.payments_rounded,
          title: 'Direct Operating Cost',
          value: '\$${cpm.toStringAsFixed(2)}/mi',
          description: 'Average cost per mile based on recent fuel ups.',
          color: colorScheme.tertiary,
        ),
      );
    }

    // 5. Maintenance Alert (25k mile intervals)
    double maxOdo = 0;
    for (var t in trips) {
      if ((t.endOdometer ?? 0) > maxOdo) maxOdo = t.endOdometer!;
    }
    for (var f in fuelEntries) {
      if ((f.odometerReading ?? 0) > maxOdo) maxOdo = f.odometerReading!;
    }

    final nextMaintenace = ((maxOdo / 25000).floor() + 1) * 25000;
    final milesUntil = nextMaintenace - maxOdo;

    if (milesUntil < 2000) {
      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.build_circle_rounded,
          title: 'Maintenance Due',
          value: '${milesUntil.round()} mi',
          description: 'Major service recommended in less than 2,000 miles.',
          color: Colors.redAccent,
        ),
      );
    }

    // 6. Top Operation Zone
    if (stateCounts.isNotEmpty) {
      final topState = stateCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.map_rounded,
          title: 'Primary Zone',
          value: topState,
          description: 'Most of your recent activity is centered in $topState.',
          color: colorScheme.outline,
        ),
      );
    }

    return list;
  }

  Widget _buildInsightTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color color,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colorScheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }
}
