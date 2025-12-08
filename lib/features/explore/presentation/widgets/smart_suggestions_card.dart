import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
import 'package:milow/core/widgets/glassy_card.dart';

class SmartSuggestionsCard extends StatelessWidget {
  final bool isDark;
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;

  const SmartSuggestionsCard({
    Key? key,
    required this.isDark,
    required this.trips,
    required this.fuelEntries,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final suggestions = _generateSuggestions();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: isDark ? Colors.amber : Colors.amber[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Suggestions',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions,
        ],
      ),
    );
  }

  List<Widget> _generateSuggestions() {
    final list = <Widget>[];

    // 1. Refill Suggestion
    // Logic: If last activity was a long trip (>300mi) and no fuel since, suggest refill.
    if (trips.isNotEmpty) {
      final lastTrip = trips.first; // Assumed sorted desc
      final lastFuelDate = fuelEntries.isNotEmpty
          ? fuelEntries.first.fuelDate
          : DateTime(2000);

      if (lastTrip.tripDate.isAfter(lastFuelDate) &&
          (lastTrip.totalDistance ?? 0) > 300) {
        list.add(
          _buildSuggestionTile(
            icon: Icons.local_gas_station,
            title: 'Tank likely low',
            subtitle:
                'You drove ${lastTrip.totalDistance?.round()} miles since last refill.',
            color: Colors.redAccent,
          ),
        );
        list.add(const SizedBox(height: 12));
      }
    }

    // 2. Weekly Mileage Check
    // Logic: If accumulated miles this week > 2000, suggest simplified check.
    double weekMiles = 0;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    for (var t in trips) {
      if (t.tripDate.isAfter(startOfWeek)) {
        weekMiles += t.totalDistance ?? 0;
      }
    }

    if (weekMiles > 2000) {
      list.add(
        _buildSuggestionTile(
          icon: Icons.build_circle_outlined,
          title: 'High Mileage Alert',
          subtitle:
              '${weekMiles.round()} miles this week. Check tire pressure.',
          color: Colors.orange,
        ),
      );
      list.add(const SizedBox(height: 12));
    }

    // 3. Fallback / Generic if empty
    if (list.isEmpty) {
      list.add(
        _buildSuggestionTile(
          icon: Icons.map,
          title: 'Plan Ahead',
          subtitle: 'Check weather for your next destination.',
          color: Colors.blue,
        ),
      );
    }

    // Remove last spacer if exists
    if (list.isNotEmpty && list.last is SizedBox) {
      list.removeLast();
    }

    return list;
  }

  Widget _buildSuggestionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
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
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          color: isDark ? Colors.grey[600] : Colors.grey[300],
        ),
      ],
    );
  }
}
