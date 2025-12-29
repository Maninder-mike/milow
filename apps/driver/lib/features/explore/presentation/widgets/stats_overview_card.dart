import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/widgets/glassy_card.dart';

class StatsOverviewCard extends StatelessWidget {
  final double totalMiles;
  final double totalFuelCost;
  final int tripCount;

  const StatsOverviewCard({
    required this.totalMiles,
    required this.totalFuelCost,
    required this.tripCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    final numberFormat = NumberFormat.decimalPattern();

    return GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Month',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.speed,
                  label: 'Miles',
                  value: numberFormat.format(totalMiles),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              VerticalDivider(
                color: Theme.of(context).colorScheme.outlineVariant,
                thickness: 1,
                width: 1,
                indent: 8,
                endIndent: 8,
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.local_gas_station,
                  label: 'Fuel Cost',
                  value: currencyFormat.format(totalFuelCost),
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              VerticalDivider(
                color: Theme.of(context).colorScheme.outlineVariant,
                thickness: 1,
                width: 1,
                indent: 8,
                endIndent: 8,
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.local_shipping,
                  label: 'Trips',
                  value: '$tripCount',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
