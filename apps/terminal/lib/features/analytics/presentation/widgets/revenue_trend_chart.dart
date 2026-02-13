import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../domain/models/revenue_data_point.dart';

class RevenueTrendChart extends StatelessWidget {
  final List<RevenueDataPoint> data;

  const RevenueTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No data available for this period.'));
    }

    final theme = FluentTheme.of(context);
    final accentColor = theme.accentColor;

    double maxY = 0;
    for (var point in data) {
      if (point.amount > maxY) maxY = point.amount;
    }
    // Add some padding to top
    maxY = maxY == 0 ? 1000 : maxY * 1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.resources.dividerStrokeColorDefault,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 5).toDouble(), // Show roughly 5 labels
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }

                final date = data[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      color: theme.resources.textFillColorSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compactSimpleCurrency().format(value),
                  style: TextStyle(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.amount);
            }).toList(),
            isCurved: true,
            color: accentColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.3),
                  accentColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.cardColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= data.length) return null;
                final date = data[index].date;
                return LineTooltipItem(
                  '${DateFormat.yMMMd().format(date)}\n${NumberFormat.simpleCurrency().format(spot.y)}',
                  TextStyle(color: theme.resources.textFillColorPrimary),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
