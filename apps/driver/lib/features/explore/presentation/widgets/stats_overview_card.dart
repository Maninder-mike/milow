import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/widgets/glassy_card.dart';

class StatsOverviewCard extends StatelessWidget {
  final double totalMiles;
  final double totalFuelCost;
  final int tripCount;
  final bool isDark;

  const StatsOverviewCard({
    required this.totalMiles,
    required this.totalFuelCost,
    required this.tripCount,
    required this.isDark,
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
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.speed,
                  label: 'Miles',
                  value: numberFormat.format(totalMiles),
                  color: Colors.blue,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_gas_station,
                  label: 'Fuel Cost',
                  value: currencyFormat.format(totalFuelCost),
                  color: Colors.orange,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_shipping,
                  label: 'Trips',
                  value: '$tripCount',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
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
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
