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
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:provider/provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockUser extends Mock implements User {}

class MockSyncQueueService extends Mock implements SyncQueueService {}

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
  late MockSyncQueueService mockSyncQueueService;
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

    // Optimize NetworkClient for tests to fail fast and avoid hangs
    NetworkClientConfig.defaultConfig = NetworkClientConfig.test;
  });

  setUp(() async {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockUser = MockUser();
    mockSyncQueueService = MockSyncQueueService();

    // Inject Mock Sync Queue
    SyncQueueService.instance = mockSyncQueueService;
    when(() => mockSyncQueueService.pendingOperations).thenReturn([]);

    registerFallbackValue(Uri.parse('http://localhost'));

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

  Widget createTestWidget(SharedPreferences prefs) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferencesService>(
          create: (_) => PreferencesService(prefs),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [DesignTokens.light],
        ),
        home: AddEntryPage(supabaseClient: mockSupabaseClient),
      ),
    );
  }

  testWidgets('AddEntryPage renders and shows initial fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(createTestWidget(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Initially in Step 0: Trip Summary
    expect(find.text('Trip Number *'), findsOneWidget);
    expect(find.text('Truck Number *'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  Future<void> navigateToStep(WidgetTester tester, int step) async {
    final nextBtn = find.text('Next Step').hitTestable();

    // Fill Step 0 requirements if moving to Step 1 or beyond
    if (step >= 1) {
      await tester.enterText(find.widgetWithText(TextFormField, 'Trip Number *'), 'T-123');
      await tester.enterText(find.widgetWithText(TextField, 'Truck Number *'), '101');
      await tester.pumpAndSettle();
      await tester.ensureVisible(nextBtn.first);
      await tester.tap(nextBtn.first);
      await tester.pumpAndSettle();
    }
    // Fill Step 1 requirements if moving to Step 2 or beyond
    if (step >= 2) {
      await tester.enterText(find.widgetWithText(TextField, 'Stop 1'), 'Chicago, IL');
      await tester.enterText(find.widgetWithText(TextField, 'Unload 1'), 'LA, CA');
      await tester.pumpAndSettle();
      await tester.ensureVisible(nextBtn.first);
      await tester.tap(nextBtn.first);
      await tester.pumpAndSettle();
    }
    // Fill Step 2 requirements if moving to Step 3
    if (step >= 3) {
      await tester.ensureVisible(nextBtn.first);
      await tester.tap(nextBtn.first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Can add and remove Trailer fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(createTestWidget(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Move to Cargo step (Step 2)
    await navigateToStep(tester, 2);

    expect(
      find.widgetWithText(TextField, 'Primary Trailer'),
      findsOneWidget,
    );

    final addButton = find.ancestor(
      of: find.byIcon(Icons.add_circle_outline),
      matching: find.byType(IconButton),
    ).hitTestable().first;

    await tester.dragUntilVisible(
      addButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Secondary Trailer'),
      findsOneWidget,
    );

    final removeIcon = find.byIcon(Icons.remove_circle_outline);
    // Find how many remove icons are present (both Primary and Secondary might have one)
    expect(removeIcon, findsAtLeastNWidgets(1));

    // Tap the last one (safest for dynamic lists)
    await tester.tap(removeIcon.last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Secondary Trailer'),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Pickup Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(createTestWidget(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Move to Logistics step (Step 1)
    await navigateToStep(tester, 1);

    expect(
      find.widgetWithText(TextField, 'Stop 1'),
      findsOneWidget,
    );

    // Pickup Add button
    final addButton = find.ancestor(
      of: find.byIcon(Icons.add_circle_outline),
      matching: find.byType(IconButton),
    ).hitTestable().at(0);

    await tester.dragUntilVisible(
      addButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final removeIcon = find.byIcon(Icons.remove_circle_outline);
    // 2 locations now, each has a remove icon.
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.remove_circle_outline),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Can add and remove Delivery Location fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(createTestWidget(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Move to Logistics step (Step 1)
    await navigateToStep(tester, 1);

    expect(
      find.widgetWithText(TextField, 'Unload 1'),
      findsOneWidget,
    );

    // Delivery Add button
    final addButton = find.ancestor(
      of: find.byIcon(Icons.add_circle_outline),
      matching: find.byType(IconButton),
    ).hitTestable().at(1);

    await tester.dragUntilVisible(
      addButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final removeIcon = find.byIcon(Icons.remove_circle_outline);
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.at(1));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.remove_circle_outline),
      findsNothing,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
