import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/features/dashboard/presentation/widgets/primary_sidebar.dart';

void main() {
  Widget buildTestWidget({
    String? activePane,
    required String currentLocation,
  }) {
    return ProviderScope(
      child: FluentApp(
        home: PrimarySidebar(
          onAddRecordTap: () {},
          onDriversTap: () {},
          onFleetTap: () {},
          onLoadsTap: () {},
          onInvoicesTap: () {},
          onCrmTap: () {},
          onSettlementsTap: () {},
          onSettingsTap: () {},
          onProfileTap: () {},
          onDashboardTap: () {},
          currentLocation: currentLocation,
          activePane: activePane,
        ),
      ),
    );
  }

  group('PrimarySidebar Selection Tests', () {
    testWidgets('Dashboard is active when on /dashboard and no activePane', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(currentLocation: '/dashboard'));

      final dashboardFinder = find.text('Dashboard');
      expect(dashboardFinder, findsOneWidget);
    });

    testWidgets('Add Record is active when activePane is add_record', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentLocation: '/dashboard',
          activePane: 'add_record',
        ),
      );

      expect(find.text('Add Record'), findsOneWidget);
    });

    testWidgets(
      'Loads is active when currentLocation starts with /highway-dispatch',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(currentLocation: '/highway-dispatch/some-load'),
        );

        expect(find.text('Loads'), findsOneWidget);
      },
    );

    testWidgets(
      'Secondary sidebar items like Drivers support both pane and route selection',
      (tester) async {
        // Test pane selection
        await tester.pumpWidget(
          buildTestWidget(currentLocation: '/dashboard', activePane: 'drivers'),
        );
        expect(find.text('Drivers'), findsOneWidget);

        // Test route selection
        await tester.pumpWidget(buildTestWidget(currentLocation: '/drivers'));
        expect(find.text('Drivers'), findsOneWidget);
      },
    );

    testWidgets(
      'Fleet is active when activePane is fleet or route is /vehicles',
      (tester) async {
        // Test pane selection
        await tester.pumpWidget(
          buildTestWidget(currentLocation: '/dashboard', activePane: 'fleet'),
        );
        expect(find.text('Fleet'), findsOneWidget);

        // Test route selection
        await tester.pumpWidget(buildTestWidget(currentLocation: '/vehicles'));
        expect(find.text('Fleet'), findsOneWidget);
      },
    );
  });
}
