import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/lane_analytics.dart';

class TopLanesList extends StatelessWidget {
  final List<LaneAnalytics> data;

  const TopLanesList({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No lane data available.'));
    }

    final theme = FluentTheme.of(context);
    final maxLoads = data
        .map((e) => e.loadCount)
        .fold<int>(0, (p, c) => p > c ? p : c);

    return ListView.builder(
      itemCount: data.length,
      padding: const EdgeInsets.only(right: 12),
      itemBuilder: (context, index) {
        final lane = data[index];
        final fraction = maxLoads > 0 ? lane.loadCount / maxLoads : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${lane.originCity} → ${lane.destinationCity}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.resources.textFillColorPrimary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${lane.loadCount} loads',
                    style: TextStyle(
                      color: theme.resources.textFillColorSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.resources.controlAltFillColorSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Avg Rate: \$${lane.averageRate.toStringAsFixed(0)}',
                style: TextStyle(
                  color: theme.resources.textFillColorTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
