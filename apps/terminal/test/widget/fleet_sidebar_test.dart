import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart' show MaterialApp, Material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/features/dashboard/presentation/widgets/fleet_sidebar.dart';
import 'package:terminal/features/dashboard/services/vehicle_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('FleetSidebar Widget Test', () {
    final testVehicles = [
      {
        'id': '1',
        'truck_number': '101',
        'vehicle_type': 'Truck',
        'license_plate': 'TX-123',
        'status': 'Active',
        'mil_status': false,
      },
      {
        'id': '2',
        'truck_number': '102',
        'vehicle_type': 'Trailer',
        'license_plate': 'CA-456',
        'status': 'Maintenance',
        'mil_status': true,
      },
    ];

    setUp(() {
      imageCache.clear();
      imageCache.clearLiveImages();

      binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
        ByteData? message,
      ) async {
        if (message == null) return null;
        final String key = utf8.decode(message.buffer.asUint8List());

        if (key == 'AssetManifest.bin') {
          final Map<String, List<Object>> manifest = {
            'packages/fluent_ui/assets/AcrylicNoise.png': [
              {'asset': 'packages/fluent_ui/assets/AcrylicNoise.png'},
            ],
          };
          return const StandardMessageCodec().encodeMessage(manifest);
        }

        if (key == 'FontManifest.json') {
          return ByteData.view(utf8.encode('[]').buffer);
        }

        if (key.contains('AcrylicNoise.png')) {
          // Return a valid 1x1 transparent PNG
          const base64Png =
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
          return ByteData.view(base64Decode(base64Png).buffer);
        }
        return null;
      });
    });

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    Widget buildTestWidget(Widget child) {
      return ProviderScope(
        overrides: [
          vehiclesListProvider.overrideWith(
            (ref) => Future.value(testVehicles),
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: FluentTheme(
              data: FluentThemeData(),
              child: Material(child: child),
            ),
          ),
        ),
      );
    }

    testWidgets('renders sidebar with header and vehicle list', (tester) async {
      await tester.pumpWidget(buildTestWidget(const FleetSidebar()));

      // Wait for Future to complete
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('FLEET'), findsOneWidget);
      expect(find.byIcon(FluentIcons.add_24_regular), findsOneWidget);

      // Verify Collapsible Section Headers (All sections are rendered)
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('BREAKDOWN'), findsOneWidget);

      // Verify Vehicle List Items (ACTIVE and MAINTENANCE are expanded by default)
      expect(find.text('101'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('TX-123'), findsOneWidget);

      // Verify ALERT badge (Uppercase)
      expect(find.text('ALERT'), findsOneWidget);
    });

    testWidgets('toggles section visibility', (tester) async {
      await tester.pumpWidget(buildTestWidget(const FleetSidebar()));

      await tester.pumpAndSettle();

      // Initially shows both (Default expanded: ACTIVE, MAINTENANCE)
      expect(find.text('101'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);

      // Tap 'MAINTENANCE' header to collapse it
      await tester.tap(find.text('MAINTENANCE'));
      await tester.pumpAndSettle();

      // Should show 101 (Active) but not 102 (Maintenance)
      expect(find.text('101'), findsOneWidget);
      expect(find.text('102'), findsNothing);

      // Tap 'MAINTENANCE' header to expand it again
      await tester.tap(find.text('MAINTENANCE'));
      await tester.pumpAndSettle();

      // Should show 102 again
      expect(find.text('102'), findsOneWidget);
    });

    testWidgets('searches vehicles by number', (tester) async {
      await tester.pumpWidget(buildTestWidget(const FleetSidebar()));

      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextBox), '102');
      await tester.pumpAndSettle();

      // Should show 102 (in list)
      // We expect 2 matches: one in search bar input, one in list item
      expect(find.text('102'), findsNWidgets(2));

      // Should not show 101
      expect(find.text('101'), findsNothing);
    });
  });
}
