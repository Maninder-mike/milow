import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../domain/models/revenue_data_point.dart';

class LoadVolumeChart extends StatelessWidget {
  final List<RevenueDataPoint> data;

  const LoadVolumeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No load data available.'));
    }

    final theme = FluentTheme.of(context);
    final accentColor = theme.accentColor;

    double maxY = 0;
    for (var point in data) {
      if (point.loadCount > maxY) maxY = point.loadCount.toDouble();
    }
    maxY = maxY == 0 ? 10 : maxY * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => theme.cardColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final index = group.x.toInt();
              if (index < 0 || index >= data.length) return null;
              final date = data[index].date;
              return BarTooltipItem(
                '${DateFormat.yMMMd().format(date)}\n${rod.toY.toInt()} Loads',
                TextStyle(color: theme.resources.textFillColorPrimary),
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
                // Show fewer labels to avoid crowding
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }

                // Show label every ~5th item
                if (data.length > 10 && index % 5 != 0) {
                  return const SizedBox.shrink();
                }

                final date = data[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      color: theme.resources.textFillColorSecondary,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30, // Space for Y-axis labels
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) {
                  return const SizedBox.shrink(); // Only integers
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4 > 1 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.resources.dividerStrokeColorDefault,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.loadCount.toDouble(),
                color: accentColor,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
