import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/core/providers/dashboard_provider.dart';
import 'package:terminal/features/dashboard/screens/overview_page.dart';

import '../helpers/mocks.mocks.dart';

void main() {
  late MockAdminDashboardService mockDashboardService;

  setUp(() {
    mockDashboardService = MockAdminDashboardService();

    // Stub KPI data
    when(mockDashboardService.getKPIData()).thenAnswer(
      (_) async => {
        'operatingRatio': 82.5,
        'maintenanceCompliance': 0.98,
        'driverRetention': 95.0,
        'accountsReceivable': {
          '30days': 15000.0,
          '60days': 5000.0,
          '90days': 2000.0,
          'total': 22000.0,
        },
      },
    );

    // Stub CPM data
    when(mockDashboardService.getCPMData()).thenAnswer(
      (_) async => [
        const FlSpot(0, 1.5),
        const FlSpot(1, 1.6),
        const FlSpot(2, 1.55),
      ],
    );

    // Stub Top Trucks data
    when(mockDashboardService.getTopTrucksData()).thenAnswer(
      (_) async => [
        {'truck': 'Truck 101', 'revenue': 25000.0},
        {'truck': 'Truck 102', 'revenue': 21000.0},
      ],
    );
  });

  testWidgets('DashboardPage loads and shows key metric cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminDashboardServiceProvider.overrideWithValue(mockDashboardService),
        ],
        child: const fluent.FluentApp(home: OverviewPage()),
      ),
    );

    // Verify title
    expect(find.text('Dashboard'), findsOneWidget);

    // Verify loading state is gone (pumpAndSettle)
    await tester.pumpAndSettle();

    // Verify card titles
    expect(find.text('OPERATING RATIO (EFFICIENCY)'), findsOneWidget);
    expect(find.text('FLEET HEALTH (MAINTENANCE)'), findsOneWidget);
    expect(find.text('DRIVER RETENTION (STABILITY)'), findsOneWidget);
    expect(find.text('ACCOUNTS RECEIVABLE (AGING)'), findsOneWidget);

    // Verify data values are displayed
    expect(find.text('82.5%'), findsOneWidget); // Operating Ratio
    expect(find.text('98%'), findsOneWidget); // Maintenance
    expect(find.text('95.0%'), findsOneWidget); // Retention
  });

  testWidgets('DashboardPage shows charts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminDashboardServiceProvider.overrideWithValue(mockDashboardService),
        ],
        child: const fluent.FluentApp(home: OverviewPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('COST PER MILE (6-MONTH TREND)'), findsOneWidget);
    expect(find.text('TOP EARNING TRUCKS (REVENUE)'), findsOneWidget);

    // Verify Chart widgets exist
    expect(find.byType(LineChart), findsOneWidget);
    expect(
      find.byType(BarChart),
      findsNWidgets(2),
    ); // AR card + Top Trucks card
  });
}
