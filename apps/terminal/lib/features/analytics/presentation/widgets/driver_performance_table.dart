import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/driver_performance.dart';

class DriverPerformanceTable extends StatelessWidget {
  final List<DriverPerformance> data;

  const DriverPerformanceTable({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No driver data available.'));
    }

    // Simple table without complex sorting state for MVP,
    // or we can use a basic List view if DataGrid is complex to setup without external package.
    // Fluent UI has no built-in DataGrid that deals with sorting deeply without state management.
    // We'll use a simple styled table structure (Row of Columns).

    final theme = FluentTheme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            color: theme.resources.layerOnAcrylicFillColorDefault,
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _HeaderCell('Driver Name')),
              Expanded(flex: 2, child: _HeaderCell('Loads')),
              Expanded(flex: 2, child: _HeaderCell('Revenue')),
              Expanded(flex: 2, child: _HeaderCell('Revenue/Load')),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final driver = data[index];
              final isEven = index % 2 == 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                color: isEven
                    ? theme.resources.layerOnAcrylicFillColorDefault
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        driver.driverName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(driver.completedLoads.toString()),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${driver.totalRevenue.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${driver.averageRevenuePerLoad.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: FluentTheme.of(context).resources.textFillColorSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
