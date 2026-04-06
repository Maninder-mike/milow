import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FuelCostTrendChart extends StatelessWidget {
  final Map<String, double> data;
  final bool isDark;

  const FuelCostTrendChart({
    required this.data,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No fuel data available')),
      );
    }

    final sortedKeys = data.keys.toList();
    final maxValue = data.values.isEmpty
        ? 100.0
        : data.values.reduce((a, b) => a > b ? a : b);

    final yMax = maxValue == 0 ? 500.0 : maxValue * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fuel Cost Trend (\$)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yMax / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: yMax / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        '\$${value.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedKeys.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          sortedKeys[index],
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (sortedKeys.length - 1).toDouble(),
              minY: 0,
              maxY: yMax,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(sortedKeys.length, (i) {
                    return FlSpot(i.toDouble(), data[sortedKeys[i]]!);
                  }),
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF7675),
                      Color(0xFFD63031),
                    ],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF7675).withValues(alpha: 0.3),
                        const Color(0xFFD63031).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
