import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class FakePostgrestTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T result;
  FakePostgrestTransformBuilder(this.result);

  @override
  Future<U> then<U>(FutureOr<U> Function(T) onValue, {Function? onError}) {
    return Future.value(onValue(result));
  }
}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-key',
    );
  });

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();

    when(() => mockUser.id).thenReturn('user1');
    when(() => mockUser.appMetadata).thenReturn({'company_id': 'comp1'});
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.currentSession).thenReturn(
      Session(
        accessToken: 'abc',
        refreshToken: 'def',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: mockUser,
      ),
    );
    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);

    when(
      () => mockSupabaseClient.from(any()),
    ).thenAnswer((_) => mockQueryBuilder);
    when(
      () => mockQueryBuilder.select(any()),
    ).thenAnswer((_) => mockFilterBuilder);
    when(
      () => mockFilterBuilder.eq(any(), any()),
    ).thenAnswer((_) => mockFilterBuilder);
    when(
      () => mockFilterBuilder.order(any(), ascending: any(named: 'ascending')),
    ).thenAnswer(
      (_) => FakePostgrestTransformBuilder<List<Map<String, dynamic>>>([]),
    );

    when(() => mockFilterBuilder.maybeSingle()).thenAnswer(
      (_) => FakePostgrestTransformBuilder<Map<String, dynamic>?>(null),
    );

    when(() => mockFilterBuilder.single()).thenAnswer(
      (_) => FakePostgrestTransformBuilder<Map<String, dynamic>>({}),
    );
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [DesignTokens.light],
        useMaterial3: true,
      ),
      home: Material(
        child: RootRestorationScope(
          restorationId: 'root',
          child: AddEntryPage(supabaseClient: mockSupabaseClient),
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
