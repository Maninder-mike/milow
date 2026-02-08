import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [DesignTokens.light],
        useMaterial3: true,
      ),
      home: const Material(
        child: RootRestorationScope(
          restorationId: 'root',
          child: AddEntryPage(),
        ),
      ),
    );
  }

  testWidgets('AddEntryPage renders and shows initial fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Trailer Number'), findsOneWidget);
    expect(find.text('Pickup Location'), findsOneWidget);
    expect(find.text('Delivery Location'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Trailer fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify initial "Trailer Number" field
    expect(find.widgetWithText(TextField, 'Trailer Number'), findsOneWidget);

    // Find Add buttons. Index 0 is Trailer Add.
    final addIcon = find.byIcon(Icons.add);

    // Tap Trailer Add (Index 0) - Usually visible at top
    await tester.tap(addIcon.at(0));
    await tester.pumpAndSettle();

    // Should now have 2 trailer fields
    expect(find.widgetWithText(TextField, 'Trailer Number'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Trailer 2'), findsOneWidget);

    // Remove buttons should appear.
    final removeIcon = find.byIcon(Icons.remove);
    expect(removeIcon, findsNWidgets(2));

    // Remove the second trailer
    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    // Back to 1
    expect(find.widgetWithText(TextField, 'Trailer Number'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Trailer 2'), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Pickup Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Pickup Location'), findsOneWidget);

    // Index 0: Trailer, 1: Border, 2: Pickup
    // We need to scroll to it.
    final addIconFinder = find.byIcon(Icons.add).at(2);

    // Scroll until visible. The main scrollable is SingleChildScrollView.
    // Finding it might be generic.
    await tester.dragUntilVisible(
      addIconFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -500), // Drag up
    );
    await tester.pumpAndSettle();

    await tester.tap(addIconFinder);
    await tester.pumpAndSettle();

    // Verify remove icons appear.
    // Note: Trailer is 1. Border 0. Pickup 2.
    // But remove icons?
    // Trailer (1) -> 0 remove icons.
    // Pickup (2) -> 2 remove icons.
    final removeIcon = find.byIcon(Icons.remove);
    expect(removeIcon, findsNWidgets(2));

    // Remove the second pickup (index 1 of the visible remove icons)
    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Delivery Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Delivery Location'), findsOneWidget);

    // Index 0: Trailer, 1: Border, 2: Pickup, 3: Delivery
    final addIconFinder = find.byIcon(Icons.add).at(3);

    // Scroll deep
    await tester.dragUntilVisible(
      addIconFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(addIconFinder);
    await tester.pumpAndSettle();

    final removeIcon = find.byIcon(Icons.remove);
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
