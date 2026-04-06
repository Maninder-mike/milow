import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/utils/unit_utils.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';
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

    return Consumer<ExploreProvider>(
      builder: (context, provider, _) {
        final suggestions = _generateSuggestions(context, provider);

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
      },
    );
  }

  List<Widget> _generateSuggestions(
    BuildContext context,
    ExploreProvider provider,
  ) {
    final list = <Widget>[];
    final colorScheme = Theme.of(context).colorScheme;
    final numberFormat = NumberFormat.decimalPattern();
    final now = DateTime.now();
    final unitSystem = provider.unitSystem;
    final isMetric = unitSystem == UnitSystem.metric;
    final distUnit = isMetric ? 'km' : 'mi';

    // 1. Data Analysis Constants
    double totalDist = 0; // Standardized (km)
    double totalFuelCost = 0;
    double totalFuelQty = 0; // Standardized (L)
    final stateCounts = <String, int>{};

    for (var t in trips) {
      totalDist += t.totalDistance ?? 0;
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
    double weekDist = 0;
    for (var t in trips) {
      if (t.tripDate.isAfter(startOfWeek)) {
        weekDist += t.totalDistance ?? 0;
      }
    }

    // Convert for display
    final displayWeekDist = isMetric ? weekDist : UnitUtils.kmToMiles(weekDist);
    final weeklyGoal = isMetric ? 4000 : 2500; // Example goals

    list.add(
      _buildInsightTile(
        context,
        icon: Icons.speed_rounded,
        title: 'Weekly Performance',
        value: '${displayWeekDist.round()} $distUnit',
        description:
            'You are at ${((displayWeekDist / weeklyGoal) * 100).toStringAsFixed(0)}% of your weekly target.',
        color: displayWeekDist > weeklyGoal * 0.8 ? Colors.green : colorScheme.primary,
        onTap: () => context.go('/dashboard'),
      ),
    );

    // 3. Fuel Efficiency (MPG or L/100km)
    if (totalDist > 0 && totalFuelQty > 0) {
      String efficiencyValue;
      bool isGood;

      if (isMetric) {
        // L/100km = (Liters / Kilometers) * 100
        final l100km = (totalFuelQty / totalDist) * 100;
        efficiencyValue = '${l100km.toStringAsFixed(1)} L/100km';
        isGood = l100km < 35.0; // Typical truck efficiency threshold
      } else {
        // MPG = Miles / Gallons
        final miles = UnitUtils.kmToMiles(totalDist);
        final gallons = UnitUtils.litersToGallons(totalFuelQty);
        final mpg = miles / gallons;
        efficiencyValue = '${mpg.toStringAsFixed(1)} MPG';
        isGood = mpg > 6.5;
      }

      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.local_gas_station_rounded,
          title: 'Fuel Efficiency',
          value: efficiencyValue,
          description: isGood
              ? 'Great job! You are driving efficiently.'
              : 'Efficiency is lower than average. Check tire pressure.',
          color: isGood ? colorScheme.secondary : Colors.orange,
        ),
      );
    }

    // 4. Cost Per Distance (CPM/CPK)
    if (totalDist > 0 && totalFuelCost > 0) {
      final displayDist = isMetric ? totalDist : UnitUtils.kmToMiles(totalDist);
      final costPerDist = totalFuelCost / displayDist;

      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.payments_rounded,
          title: 'Direct Operating Cost',
          value: '${UnitUtils.getCurrencySymbol(context.read<PreferencesService>().getCurrency())} ${costPerDist.toStringAsFixed(2)}/$distUnit',
          description: 'Average cost per $distUnit based on recent fuel ups.',
          color: colorScheme.tertiary,
        ),
      );
    }

    // 5. Maintenance Alert
    double maxOdo = 0; // Standardized (km)
    for (var t in trips) {
      if ((t.endOdometer ?? 0) > maxOdo) maxOdo = t.endOdometer!;
    }
    for (var f in fuelEntries) {
      if ((f.odometerReading ?? 0) > maxOdo) maxOdo = f.odometerReading!;
    }

    final interval = isMetric ? 40000.0 : 25000.0;
    final nextMaintenance = ((maxOdo / interval).floor() + 1) * interval;
    final distUntil = nextMaintenance - maxOdo;
    final displayDistUntil = isMetric ? distUntil : UnitUtils.kmToMiles(distUntil);

    if (displayDistUntil < (isMetric ? 3000 : 2000)) {
      list.add(const SizedBox(height: 16));
      list.add(
        _buildInsightTile(
          context,
          icon: Icons.build_circle_rounded,
          title: 'Maintenance Due',
          value: '${displayDistUntil.round()} $distUnit',
          description: 'Major service recommended in less than ${numberFormat.format(isMetric ? 3000 : 2000)} $distUnit.',
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
