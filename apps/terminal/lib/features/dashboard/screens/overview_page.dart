import 'package:fluent_ui/fluent_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/admin_dashboard_service.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final _service = AdminDashboardService();

  // Future variables
  late Future<Map<String, dynamic>> _kpiFuture;
  late Future<List<FlSpot>> _cpmFuture;
  late Future<List<Map<String, dynamic>>> _trucksFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _kpiFuture = _service.getKPIData();
      _cpmFuture = _service.getCPMData();
      _trucksFuture = _service.getTopTrucksData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: FilledButton(
          onPressed: _refresh,
          child: const Text('Refresh Data'),
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row: Operating Ratio & Maintenance & AR
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine layout based on width
                if (constraints.maxWidth > 1200) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildOperatingRatioCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMaintenanceCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDriverRetentionCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildARCard()),
                    ],
                  );
                } else if (constraints.maxWidth > 800) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildOperatingRatioCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildMaintenanceCard()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDriverRetentionCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildARCard()),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildOperatingRatioCard(),
                      const SizedBox(height: 16),
                      _buildMaintenanceCard(),
                      const SizedBox(height: 16),
                      _buildDriverRetentionCard(),
                      const SizedBox(height: 16),
                      _buildARCard(),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // Middle Row: CPM Chart
            _buildCPMChartCard(),

            const SizedBox(height: 16),

            // Bottom Row: Top Trucks
            _buildTopTrucksCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Widget child,
    Widget? extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),
              if (extra != null) extra,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildOperatingRatioCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());
        final ratio = snapshot.data!['operatingRatio'] as double;
        final color = ratio < 85
            ? Colors.green
            : (ratio < 95 ? Colors.orange : Colors.red);

        return _buildCard(
          title: 'Operating Ratio (Efficiency)',
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: ProgressRing(
                        value: ratio,
                        backgroundColor: FluentTheme.of(
                          context,
                        ).resources.controlStrokeColorDefault,
                        activeColor: color,
                        strokeWidth: 12,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${ratio.toStringAsFixed(1)}%',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          'Efficiency',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (ratio < 85)
                const InfoBar(
                  title: Text('Excellent'),
                  content: Text('Your fleet is running efficiently.'),
                  severity: InfoBarSeverity.success,
                  isLong: false,
                )
              else
                InfoBar(
                  title: const Text('Attention Needed'),
                  content: const Text('Expenses are high relative to revenue.'),
                  severity: ratio < 95
                      ? InfoBarSeverity.warning
                      : InfoBarSeverity.error,
                  isLong: false,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());
        final compliance = snapshot.data!['maintenanceCompliance'] as double;
        final percentage = (compliance * 100).toInt();

        return _buildCard(
          title: 'Fleet Health (Maintenance)',
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: ProgressRing(
                        value: percentage.toDouble(),
                        backgroundColor: FluentTheme.of(
                          context,
                        ).resources.controlStrokeColorDefault,
                        activeColor: Colors.blue,
                        strokeWidth: 12,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percentage%',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Compliance',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'On-time Service',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverRetentionCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());
        final retention = snapshot.data!['driverRetention'] as double;

        return _buildCard(
          title: 'Driver Retention (Stability)',
          child: SizedBox(
            height: 178, // Match height of other cards roughly
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${retention.toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stability Rate',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildARCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _kpiFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());
        final data =
            snapshot.data!['accountsReceivable'] as Map<String, dynamic>;

        // Data for stacked bar
        final days30 = data['30days'] as double;
        final days60 = data['60days'] as double;
        final days90 = data['90days'] as double;
        final total = data['total'];

        return _buildCard(
          title: 'Accounts Receivable (Aging)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NumberFormat.simpleCurrency().format(total),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Outstanding',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    maxY: total * 1.2,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(show: false),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: total,
                            width: 50,
                            borderRadius: BorderRadius.circular(4),
                            rodStackItems: [
                              BarChartRodStackItem(0, days30, Colors.green),
                              BarChartRodStackItem(
                                days30,
                                days30 + days60,
                                Colors.orange,
                              ),
                              BarChartRodStackItem(
                                days30 + days60,
                                days30 + days60 + days90,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('0-30', Colors.green),
                  _buildLegendItem('31-60', Colors.orange),
                  _buildLegendItem('60+', Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildCPMChartCard() {
    return FutureBuilder<List<FlSpot>>(
      future: _cpmFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());

        final spots = snapshot.data!;
        return _buildCard(
          title: 'Cost Per Mile (6-Month Trend)',
          child: SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                        ];
                        if (value.toInt() >= 0 &&
                            value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopTrucksCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _trucksFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: ProgressRing());

        final trucks = snapshot.data!;

        return _buildCard(
          title: 'Top Earning Trucks (Revenue)',
          child: SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 30000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < trucks.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trucks[value.toInt()]['truck']
                                  .split(' ')
                                  .last, // Show just number for space
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: trucks.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value['revenue'],
                        color: FluentTheme.of(context).accentColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 30000,
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
