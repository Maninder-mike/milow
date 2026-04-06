import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/preferences_service.dart';

class TripFrequencyChart extends StatelessWidget {
  final Map<String, double> data;
  final bool isDark;
  final UnitSystem unitSystem;

  const TripFrequencyChart({
    required this.data,
    required this.isDark,
    required this.unitSystem,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No trip data available')),
      );
    }

    final sortedKeys = data.keys.toList();
    final maxValue = data.values.isEmpty
        ? 100.0
        : data.values.reduce((a, b) => a > b ? a : b);

    // Ensure we have a reasonable max for Y axis
    final yMax = maxValue == 0 ? 1000.0 : maxValue * 1.2;
    final unitLabel = unitSystem == UnitSystem.metric ? 'Kilometers' : 'Miles';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Distance ($unitLabel)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      isDark ? Colors.grey[800]! : Colors.white,
                  tooltipBorder: BorderSide(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${sortedKeys[group.x]}\n',
                      GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                       ),
                       children: [
                         TextSpan(
                           text: '${rod.toY.toStringAsFixed(0)} ${unitSystem == UnitSystem.metric ? 'km' : 'mi'}',
                           style: GoogleFonts.inter(
                             color: Colors.blueAccent,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                       ],
                     );
                   },
                 ),
               ),
               titlesData: FlTitlesData(
                 show: true,
                 bottomTitles: AxisTitles(
                   sideTitles: SideTitles(
                     showTitles: true,
                     getTitlesWidget: (value, meta) {
                       final index = value.toInt();
                       if (index < 0 || index >= sortedKeys.length) {
                         return const SizedBox.shrink();
                       }
                       return SideTitleWidget(
                         meta: meta,
                         space: 8,
                         child: Text(
                           sortedKeys[index],
                           style: GoogleFonts.inter(
                             color: isDark ? Colors.white70 : Colors.black54,
                             fontSize: 10,
                           ),
                         ),
                       );
                     },
                     reservedSize: 30,
                   ),
                 ),
                 leftTitles: const AxisTitles(
                   sideTitles: SideTitles(showTitles: false),
                 ),
                 topTitles: const AxisTitles(
                   sideTitles: SideTitles(showTitles: false),
                 ),
                 rightTitles: const AxisTitles(
                   sideTitles: SideTitles(showTitles: false),
                 ),
               ),
               gridData: const FlGridData(show: false),
               borderData: FlBorderData(show: false),
               barGroups: List.generate(sortedKeys.length, (i) {
                 return BarChartGroupData(
                   x: i,
                   barRods: [
                     BarChartRodData(
                       toY: data[sortedKeys[i]]!,
                       gradient: LinearGradient(
                         colors: [
                           const Color(0xFF6C5CE7),
                           const Color(0xFF6C5CE7).withValues(alpha: 0.6),
                         ],
                         begin: Alignment.bottomCenter,
                         end: Alignment.topCenter,
                       ),
                       width: 16,
                       borderRadius: const BorderRadius.vertical(
                         top: Radius.circular(4),
                       ),
                     ),
                   ],
                 );
               }),
             ),
           ),
         ),
       ],
     );
   }
 }
