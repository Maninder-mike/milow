import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/providers/supabase_provider.dart';
import 'package:terminal/features/dashboard/screens/pickup/pickup_page.dart';
import 'package:terminal/core/widgets/form_widgets.dart';

// We'll generate mocks if needed, but for now we'll use a simple manual mock or rely on existing ones if they were visible.
// Since I can't see the generated mocks, I'll define a simple one here for the client.
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
  });

  Future<void> setSurfaceSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [supabaseClientProvider.overrideWithValue(mockSupabaseClient)],
      child: FluentApp(home: child),
    );
  }

  group('PickUpPage Widget Tests', () {
    testWidgets('renders all logistics flags correctly', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      await tester.pumpWidget(
        createTestWidget(const PickUpPage(isDialog: true)),
      );

      // Check for some key flags
      expect(
        find.text('LOGISTICS & INSTRUCTIONS'),
        findsOneWidget,
      ); // Header text in uppercase in _buildSectionHeader
      expect(find.text('PPE Required'), findsOneWidget); // Chip label
      expect(find.text('Hazmat'), findsOneWidget);
      expect(find.text('TWIC/Port'), findsOneWidget);
      expect(find.text('No Touch'), findsOneWidget);
      expect(find.text('Liftgate Req.'), findsOneWidget);

      // Disambiguate Gate Code (Text field label vs Chip)
      expect(
        find.widgetWithText(FluentOptionChip, 'Gate Code'),
        findsOneWidget,
      );

      // Verify total count of FluentOptionChip (should be 21)
      expect(find.byType(FluentOptionChip), findsNWidgets(21));
    });

    testWidgets('populates fields correctly in Edit Mode', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      final mockData = {
        'id': 'test-id',
        'shipper_name': 'Test Shipper Corp',
        'address': '123 Enterprise Way',
        'city': 'Toronto',
        'is_hazmat': true,
        'is_temp_control': true,
        'is_ppe_required': false,
        'commodity': 'Electronics',
        'weight': 5000.0,
      };

      await tester.pumpWidget(
        createTestWidget(PickUpPage(pickupData: mockData, isDialog: true)),
      );

      // Verify text fields
      expect(find.text('Test Shipper Corp'), findsOneWidget);
      expect(find.text('123 Enterprise Way'), findsOneWidget);
      expect(find.text('Electronics'), findsOneWidget);

      // Verify chips state
      // We can find the FluentOptionChip and check its 'value' property
      final hazmatChip = tester.widget<FluentOptionChip>(
        find.widgetWithText(FluentOptionChip, 'Hazmat'),
      );
      expect(hazmatChip.value, isTrue);

      final ppeChip = tester.widget<FluentOptionChip>(
        find.widgetWithText(FluentOptionChip, 'PPE Required'),
      );
      expect(ppeChip.value, isFalse);
    });

    testWidgets('toggling a logistics chip updates UI state', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      await tester.pumpWidget(
        createTestWidget(const PickUpPage(isDialog: true)),
      );

      final hazmatFinder = find
          .widgetWithText(FluentOptionChip, 'Hazmat')
          .first;
      await tester.ensureVisible(hazmatFinder);
      await tester.pumpAndSettle();

      var hazmatChip = tester.widget<FluentOptionChip>(hazmatFinder);
      expect(hazmatChip.value, isFalse);

      // Tap the chip
      await tester.tap(hazmatFinder);
      await tester.pumpAndSettle();

      // Check updated state
      hazmatChip = tester.widget<FluentOptionChip>(hazmatFinder);
      expect(hazmatChip.value, isTrue);
    });
  });
}
