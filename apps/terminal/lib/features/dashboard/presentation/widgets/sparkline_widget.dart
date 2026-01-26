import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';

class SparklineWidget extends StatelessWidget {
  final List<double> data;
  final Color color;

  const SparklineWidget({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: data.length.toDouble() - 1,
        minY: 0,
        maxY: (data.reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
