import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StateDistributionChart extends StatefulWidget {
  final Map<String, double> data;
  final bool isDark;

  const StateDistributionChart({
    required this.data,
    required this.isDark,
    super.key,
  });

  @override
  State<StateDistributionChart> createState() => _StateDistributionChartState();
}

class _StateDistributionChartState extends State<StateDistributionChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No state data available')),
      );
    }

    // Process data to get top 5 states and group others
    final sortedData = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final totalDistance = widget.data.values.fold(0.0, (sum, val) => sum + val);
    
    final List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00B894),
      const Color(0xFFFF7675),
      const Color(0xFFFDCB6E),
      const Color(0xFF0984E3),
      const Color(0xFF636E72),
    ];

    final int limit = sortedData.length > 5 ? 5 : sortedData.length;
    double otherDistance = 0;

    for (int i = 0; i < sortedData.length; i++) {
       if (i < limit) {
         final isTouched = i == touchedIndex;
         final fontSize = isTouched ? 16.0 : 12.0;
         final radius = isTouched ? 60.0 : 50.0;
         final widgetSize = isTouched ? 45.0 : 35.0;
         // Removed unused opacity variable

         sections.add(
           PieChartSectionData(
             color: colors[i % colors.length],
             value: sortedData[i].value,
             title: '${((sortedData[i].value / totalDistance) * 100).toStringAsFixed(0)}%',
             radius: radius,
             titleStyle: GoogleFonts.inter(
               fontSize: fontSize,
               fontWeight: FontWeight.bold,
               color: Colors.white,
             ),
             badgeWidget: isTouched ? _Badge(sortedData[i].key, size: widgetSize) : null,
             badgePositionPercentageOffset: .98,
           ),
         );
       } else {
         otherDistance += sortedData[i].value;
       }
    }

    if (otherDistance > 0) {
      final isTouched = touchedIndex == limit;
      sections.add(
        PieChartSectionData(
          color: colors[limit % colors.length],
          value: otherDistance,
          title: '${((otherDistance / totalDistance) * 100).toStringAsFixed(0)}%',
          radius: isTouched ? 60.0 : 50.0,
          titleStyle: GoogleFonts.inter(
            fontSize: isTouched ? 16.0 : 12.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: isTouched ? _Badge('OTH', size: isTouched ? 45.0 : 35.0) : null,
          badgePositionPercentageOffset: .98,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distance by State',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: List.generate(sections.length, (i) {
             final label = i < limit ? sortedData[i].key : 'Other';
             return _LegendItem(
               color: colors[i % colors.length],
               text: label,
               isDark: widget.isDark,
             );
          }),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final double size;

  const _Badge(this.text, {required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
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
