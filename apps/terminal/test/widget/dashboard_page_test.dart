import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/features/dashboard/screens/overview_page.dart';
import 'package:terminal/core/providers/shared_preferences_provider.dart';
import 'package:terminal/features/dashboard/presentation/providers/dashboard_metrics_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'fake-anon-key',
      );
    } catch (_) {}
  });

  testWidgets('OverviewPage loads and shows enterprise dashboard', (
    tester,
  ) async {
    // Set a large surface size to prevent overflow errors on "Desktop" widgets
    tester.view.physicalSize = const fluent.Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mockMetricsData = DashboardMetrics(
      activeLoads: 12,
      awaitingDispatch: 4,
      revenueMTD: 45200.50,
      fleetHealthPercent: 92.5,
      criticalAlertsCount: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dashboardMetricsProvider.overrideWith(
            (ref) => Future.value(mockMetricsData),
          ),
        ],
        child: const fluent.FluentApp(home: OverviewPage()),
      ),
    );

    // Initial load
    // Initial load
    // Initial load
    await tester.pump(); // Start the build
    // Wait for all EntranceFader delays (max 500ms + animation 400ms) = ~900ms
    // We pump for 2 seconds to be safe and avoid "pumpAndSettle" timeouts from infinite animations
    await tester.pump(const Duration(seconds: 2));

    // Verify Header
    expect(find.text('Dashboard Overview'), findsOneWidget);

    // Verify Metrics are displayed
    expect(find.text('12'), findsOneWidget); // Active Loads
    expect(find.text('4'), findsOneWidget); // Awaiting Dispatch
    expect(find.text('92.5%'), findsOneWidget); // Fleet Health
    expect(find.text('1'), findsOneWidget); // Critical Alerts

    // Verify Quick Actions
    expect(find.text('New Load'), findsOneWidget);
    expect(find.text('Assign Driver'), findsOneWidget);
  });
}
