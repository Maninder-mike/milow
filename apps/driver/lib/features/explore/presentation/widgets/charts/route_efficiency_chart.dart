import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RouteEfficiencyChart extends StatelessWidget {
  final Map<String, Map<String, double>> data;
  final bool isDark;

  const RouteEfficiencyChart({
    required this.data,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No efficiency data available')),
      );
    }

    final months = data.keys.toList();
    final List<FlSpot> loadedSpots = [];
    final List<FlSpot> emptySpots = [];

    double maxY = 0;

    for (int i = 0; i < months.length; i++) {
      final monthData = data[months[i]]!;
      final loaded = monthData['Loaded'] ?? 0;
      final empty = monthData['Empty'] ?? 0;
      
      loadedSpots.add(FlSpot(i.toDouble(), loaded));
      emptySpots.add(FlSpot(i.toDouble(), empty));

      if (loaded > maxY) maxY = loaded;
      if (empty > maxY) maxY = empty;
    }

    maxY = maxY == 0 ? 1000 : maxY * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leg Efficiency (Loaded vs Empty)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 8,
                        child: Text(
                          months[index],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      );
                    },
                    reservedSize: 22,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _lineBarData(loadedSpots, const Color(0xFF6C63FF), 'Loaded'),
                _lineBarData(emptySpots, const Color(0xFFFF7675), 'Empty'),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isLoaded = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isLoaded ? 'Loaded' : 'Empty'}: ${spot.y.toStringAsFixed(0)}',
                        GoogleFonts.inter(
                          color: isLoaded ? const Color(0xFF6C63FF) : const Color(0xFFFF7675),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              minY: 0,
              maxY: maxY,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             _Legend(color: const Color(0xFF6C63FF), text: 'Loaded', isDark: isDark),
             const SizedBox(width: 24),
             _Legend(color: const Color(0xFFFF7675), text: 'Empty Leg', isDark: isDark),
           ],
        ),
      ],
    );
  }

  LineChartBarData _lineBarData(List<FlSpot> spots, Color color, String label) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  final bool isDark;

  const _Legend({required this.color, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
