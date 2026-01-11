import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/providers/supabase_provider.dart';
import 'package:terminal/features/dashboard/screens/deliver/delivery_page.dart';
import 'package:terminal/core/widgets/form_widgets.dart';

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

  group('DeliveryPage Widget Tests', () {
    testWidgets('renders all logistics flags correctly', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      await tester.pumpWidget(
        createTestWidget(const DeliveryPage(isDialog: true)),
      );

      // Check for section header
      expect(find.text('LOGISTICS & INSTRUCTIONS'), findsOneWidget);

      // Check for some key flags
      expect(find.text('PPE Required'), findsOneWidget);
      expect(find.text('Lumper Req.'), findsOneWidget);

      // Disambiguate Gate Code
      expect(
        find.widgetWithText(FluentOptionChip, 'Gate Code'),
        findsOneWidget,
      );

      expect(find.text('Inside Deliv.'), findsOneWidget);

      // Verify total count of FluentOptionChip (should be 17)
      expect(find.byType(FluentOptionChip), findsNWidgets(17));
    });

    testWidgets('populates fields correctly in Edit Mode', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      final mockData = {
        'id': 'test-id',
        'receiver_name': 'Test Receiver Corp',
        'address': '456 Delivery Lane',
        'city': 'Vaughan',
        'is_liftgate_required': true,
        'is_residential': true,
        'is_hazmat': false,
        'commodity': 'Frozen Goods',
        'weight': 3500.0,
      };

      await tester.pumpWidget(
        createTestWidget(DeliveryPage(receiverData: mockData, isDialog: true)),
      );

      // Verify text fields
      expect(find.text('Test Receiver Corp'), findsOneWidget);
      expect(find.text('456 Delivery Lane'), findsOneWidget);
      expect(find.text('Frozen Goods'), findsOneWidget);

      // Verify chips state
      final liftgateChip = tester.widget<FluentOptionChip>(
        find.widgetWithText(FluentOptionChip, 'Liftgate Req.'),
      );
      expect(liftgateChip.value, isTrue);

      final hazmatChip = tester.widget<FluentOptionChip>(
        find.widgetWithText(FluentOptionChip, 'Hazmat'),
      );
      expect(hazmatChip.value, isFalse);
    });

    testWidgets('toggling a logistics chip updates UI state', (
      WidgetTester tester,
    ) async {
      await setSurfaceSize(tester);
      await tester.pumpWidget(
        createTestWidget(const DeliveryPage(isDialog: true)),
      );

      final residentialFinder = find
          .widgetWithText(FluentOptionChip, 'Residential')
          .first;
      await tester.ensureVisible(residentialFinder);
      await tester.pumpAndSettle();

      var residentialChip = tester.widget<FluentOptionChip>(residentialFinder);
      expect(residentialChip.value, isFalse);

      // Tap the chip
      await tester.tap(residentialFinder);
      await tester.pumpAndSettle();

      // Check updated state
      residentialChip = tester.widget<FluentOptionChip>(residentialFinder);
      expect(residentialChip.value, isTrue);
    });
  });
}
