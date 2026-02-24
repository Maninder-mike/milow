import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/core/constants/design_tokens.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockUser extends Mock implements User {}

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
  late MockGoTrueClient mockGoTrueClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockUser mockUser;
  // ignore: unused_local_variable
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp();

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });

    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-key',
    );

    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockUser = MockUser();

    when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(() => mockGoTrueClient.currentUser).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('user123');

    // Mock profiles query
    when(
      () => mockSupabaseClient.from(any()),
    ).thenAnswer((_) => mockQueryBuilder);
    when(
      () => mockQueryBuilder.select(any()),
    ).thenAnswer((_) => mockFilterBuilder);
    when(
      () => mockFilterBuilder.eq(any(), any()),
    ).thenAnswer((_) => mockFilterBuilder);
    when(() => mockFilterBuilder.maybeSingle()).thenAnswer(
      (_) => FakePostgrestTransformBuilder<Map<String, dynamic>?>({
        'id': 'user123',
        'full_name': 'John Doe',
        'driver_type': 'company',
      }),
    );

    // Mock order and other transform builders
    when(
      () => mockFilterBuilder.order(any(), ascending: any(named: 'ascending')),
    ).thenAnswer(
      (_) => FakePostgrestTransformBuilder<List<Map<String, dynamic>>>([]),
    );

    when(() => mockFilterBuilder.limit(any())).thenAnswer(
      (_) => FakePostgrestTransformBuilder<List<Map<String, dynamic>>>([]),
    );
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [DesignTokens.light]),
      home: AddEntryPage(supabaseClient: mockSupabaseClient),
    );
  }

  testWidgets('AddEntryPage renders and shows initial fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pump(); // Start building
    await tester.pump(const Duration(milliseconds: 500)); // Allow async loading

    final tripTab = find.byType(SingleChildScrollView).at(0);
    expect(
      find.descendant(of: tripTab, matching: find.text('Trailer 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tripTab, matching: find.text('Pickup Location')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tripTab, matching: find.text('Delivery Location')),
      findsOneWidget,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Trailer fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final tripTab = find.byType(SingleChildScrollView).at(0);
    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Trailer 1'),
      ),
      findsOneWidget,
    );

    final addIcon = find.descendant(
      of: tripTab,
      matching: find.byIcon(Icons.add_circle_outline),
    );

    await tester.tap(addIcon.at(0));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Trailer 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Trailer 2'),
      ),
      findsOneWidget,
    );

    final removeIcon = find.descendant(
      of: tripTab,
      matching: find.byIcon(Icons.remove_circle_outline),
    );
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Trailer 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Trailer 2'),
      ),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Pickup Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final tripTab = find.byType(SingleChildScrollView).at(0);
    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Pickup Location'),
      ),
      findsOneWidget,
    );

    // Pickup Add button is index 1 (index 0 is Border Crossing)
    final addIconFinder = find
        .descendant(of: tripTab, matching: find.byIcon(Icons.add))
        .at(1);

    await tester.dragUntilVisible(
      addIconFinder,
      tripTab,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(addIconFinder);
    await tester.pumpAndSettle();

    final removeIcon = find.descendant(
      of: tripTab,
      matching: find.byIcon(Icons.remove),
    );
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: tripTab, matching: find.byIcon(Icons.remove)),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Delivery Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final tripTab = find.byType(SingleChildScrollView).at(0);
    expect(
      find.descendant(
        of: tripTab,
        matching: find.widgetWithText(TextField, 'Delivery Location'),
      ),
      findsOneWidget,
    );

    // Delivery Add button is index 2
    final addIconFinder = find
        .descendant(of: tripTab, matching: find.byIcon(Icons.add))
        .at(2);

    await tester.dragUntilVisible(
      addIconFinder,
      tripTab,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(addIconFinder);
    await tester.pumpAndSettle();

    final removeIcon = find.descendant(
      of: tripTab,
      matching: find.byIcon(Icons.remove),
    );
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: tripTab, matching: find.byIcon(Icons.remove)),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
