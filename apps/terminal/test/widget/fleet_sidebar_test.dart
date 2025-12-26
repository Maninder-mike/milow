import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/dashboard/presentation/widgets/fleet_sidebar.dart';
import '../../lib/features/dashboard/services/vehicle_service.dart';

void main() {
  group('FleetSidebar Widget Test', () {
    final testVehicles = [
      {
        'id': '1',
        'vehicle_number': '101',
        'vehicle_type': 'Truck',
        'license_plate': 'TX-123',
        'status': 'Active',
        'mil_status': false,
      },
      {
        'id': '2',
        'vehicle_number': '102',
        'vehicle_type': 'Trailer',
        'license_plate': 'CA-456',
        'status': 'Maintenance',
        'mil_status': true,
      },
    ];

    testWidgets('renders sidebar with header and vehicle list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesListProvider.overrideWith(
              (ref) => Future.value(testVehicles),
            ),
          ],
          child: const FluentApp(home: ScaffoldPage(content: FleetSidebar())),
        ),
      );

      // Wait for Future to complete
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('FLEET'), findsOneWidget);
      expect(find.byIcon(FluentIcons.add_24_regular), findsOneWidget);

      // Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      // 'Active' is in the chip list AND in the vehicle list item status badge
      expect(find.text('Active'), findsAtLeastNWidgets(1));

      // Verify Vehicle List Items
      expect(find.text('101'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('TX-123'), findsOneWidget);

      // Verify Status Badges
      expect(
        find.text('Active'),
        findsAtLeastNWidgets(1),
      ); // One in filter, one in badge
      expect(find.text('Maintenance'), findsAtLeastNWidgets(1));

      // Verify Alert Icon for vehicle with issue
      expect(find.text('Alert'), findsOneWidget);
    });

    testWidgets('filters vehicles when chip is clicked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesListProvider.overrideWith(
              (ref) => Future.value(testVehicles),
            ),
          ],
          child: const FluentApp(home: ScaffoldPage(content: FleetSidebar())),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows both
      expect(find.text('101'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);

      // Tap 'Active' filter
      // Use .first because 'Active' matches both the chip and the badge in the list
      await tester.tap(find.text('Active').first);
      await tester.pumpAndSettle();

      // Should show 101 (Active) but not 102 (Maintenance)
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('101')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('102')),
        findsNothing,
      );
    });

    testWidgets('searches vehicles by number', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesListProvider.overrideWith(
              (ref) => Future.value(testVehicles),
            ),
          ],
          child: const FluentApp(home: ScaffoldPage(content: FleetSidebar())),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextBox), '102');
      await tester.pumpAndSettle();

      // Should show 102 (in list)
      // We expect 2 matches: one in search bar input, one in list item
      expect(find.text('102'), findsNWidgets(2));
      // Verifying specifically in the list
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('102')),
        findsOneWidget,
      );

      // Should not show 101
      expect(find.text('101'), findsNothing);
    });
  });
}
