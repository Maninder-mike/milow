import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/widgets/glassy_card.dart';
import 'package:go_router/go_router.dart';

class SmartSuggestionsCard extends StatelessWidget {
  final bool isDark;
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;

  const SmartSuggestionsCard({
    required this.isDark,
    required this.trips,
    required this.fuelEntries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = _generateSuggestions(context);

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

  List<Widget> _generateSuggestions(BuildContext context) {
    final list = <Widget>[];
    final now = DateTime.now();

    // 1. Weekly Progress (Always show)
    // Logic: Sum miles for current week (Mon-Sun)
    double weekMiles = 0;
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    for (var t in trips) {
      if (t.tripDate.isAfter(startOfWeek)) {
        weekMiles += t.totalDistance ?? 0;
      }
    }

    list.add(
      _buildSuggestionTile(
        icon: Icons.trending_up,
        title: 'Weekly Progress',
        subtitle: '${weekMiles.round()} miles driven this week.',
        color: weekMiles > 0 ? Colors.green : Colors.blueGrey,
        onTap: () => context.go('/dashboard'),
      ),
    );
    list.add(const SizedBox(height: 12));

    // 2. Incomplete Logs
    // Logic: Check recent 3 trips for missing odometer readings
    bool hasIncompleteLog = false;
    for (var t in trips.take(3)) {
      if (t.startOdometer == null || t.endOdometer == null) {
        hasIncompleteLog = true;
        break;
      }
    }
    if (hasIncompleteLog) {
      list.add(
        _buildSuggestionTile(
          icon: Icons.warning_amber_rounded,
          title: 'Incomplete Log',
          subtitle: 'A recent trip is missing odometer readings.',
          color: Colors.orange,
          onTap: () => context.go('/dashboard'),
        ),
      );
      list.add(const SizedBox(height: 12));
    }

    // 3. Rest Recommendation (Fatigue Risk)
    // Logic: If last trip was today AND > 500 miles, suggest rest.
    if (trips.isNotEmpty) {
      final lastTrip = trips.first;
      final isToday =
          lastTrip.tripDate.year == now.year &&
          lastTrip.tripDate.month == now.month &&
          lastTrip.tripDate.day == now.day;

      if (isToday && (lastTrip.totalDistance ?? 0) > 500) {
        list.add(
          _buildSuggestionTile(
            icon: Icons.bed_outlined, // or hotel class
            title: 'Rest Recommended',
            subtitle: 'You drove a long distance today. Take a break.',
            color: Colors.indigoAccent,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Find safety rest areas nearby.')),
              );
            },
          ),
        );
        list.add(const SizedBox(height: 12));
      }
    }

    // 4. Low Fuel / Refill Check (Optimized)
    // Logic: If > 400 miles since last fuel
    if (trips.isNotEmpty) {
      final lastTrip = trips.first;
      final lastFuelDate = fuelEntries.isNotEmpty
          ? fuelEntries.first.fuelDate
          : DateTime(2000);

      // If driven significant miles since last fuel
      if (lastTrip.tripDate.isAfter(lastFuelDate) &&
          (lastTrip.totalDistance ?? 0) > 400) {
        list.add(
          _buildSuggestionTile(
            icon: Icons.local_gas_station,
            title: 'Refill Suggested',
            subtitle:
                '${lastTrip.totalDistance?.round()} miles since last fill-up.',
            color: Colors.redAccent,
            onTap: () => context.push('/add-entry'),
          ),
        );
        list.add(const SizedBox(height: 12));
      }
    }

    // Fallback if only weekly progress is shown (and it's 0)
    if (list.length <= 2 && weekMiles == 0) {
      list.add(
        _buildSuggestionTile(
          icon: Icons.add_road,
          title: 'Start Your Week',
          subtitle: 'Log your first trip to track performance.',
          color: Colors.blue,
          onTap: () => context.push('/add-entry'),
        ),
      );
    }

    // Cleanup spacing
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
        ),
      ),
    );
  }
}
