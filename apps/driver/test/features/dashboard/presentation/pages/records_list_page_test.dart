import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

// Mock Connectivity Service
class MockConnectivityService extends ConnectivityService {
  MockConnectivityService() : super.testing();

  @override
  bool get isOnline => false; // Force offline to use local stores

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(false);
}

class MockSyncQueueService extends Mock implements SyncQueueService {}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Setup Mock Path Provider via MethodChannel
    tempDir = await Directory.systemTemp.createTemp();

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase for testing (to avoid Supabase.instance error)
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-key',
    );

    // Optimize NetworkClient for tests to fail fast and avoid hangs
    NetworkClientConfig.defaultConfig = NetworkClientConfig.test;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    // Inject Mock Connectivity
    ConnectivityService.instance = MockConnectivityService();

    // Inject Mock Sync Queue
    final mockSyncQueue = MockSyncQueueService();
    when(() => mockSyncQueue.pendingOperations).thenReturn([]);
    SyncQueueService.instance = mockSyncQueue;

    // Inject Mock User ID
    TripRepository.mockUserId = 'test-user';
    FuelRepository.mockUserId = 'test-user';

    // Clear DB
    await driverDatabase.delete(driverDatabase.trips).go();
    await driverDatabase.delete(driverDatabase.fuelEntries).go();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final prefService = PreferencesService(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferencesService>.value(value: prefService),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: const [DesignTokens.light],
          ),
          home: const RecordsListPage(),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    // Trigger initState and first frame
    await tester.pump();

    // Wait for the loading spinner to disappear and UI to settle
    // Manual loop is safer than pumpAndSettle when infinite animations (spinners) are present.
    bool isLoadingGone = false;
    for (int i = 0; i < 50; i++) {
      // Increase to 50 tries (2.5 seconds)
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        isLoadingGone = true;
        break;
      }
    }

    if (!isLoadingGone) {
      debugPrint(
        '[pumpPage] WARNING: CircularProgressIndicator still visible after timeout',
      );
    }

    // Final settle for any other transitions
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders successfully with empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text('All Records'), findsOneWidget);
    expect(find.byType(SliverAppBar), findsWidgets);

    // Check for the mapped text using our new key
    final emptyTextFinder = find.byKey(const Key('empty_state_text'));
    expect(emptyTextFinder, findsOneWidget);

    final Text emptyTextWidget = tester.widget<Text>(emptyTextFinder);
    expect(emptyTextWidget.data, 'No trips or fuel entries yet');
  });

  testWidgets('loads and displays trips and fuel', (tester) async {
    // Seed Data into DriverDatabase directly
    final trip = TripsCompanion.insert(
      id: 'trip-1',
      userId: const Value('test-user'),
      tripNumber: '12345',
      truckNumber: 'T-100',
      tripDate: DateTime(2023, 10, 1),
      pickupLocations: const Value('["Chicago, IL"]'),
      deliveryLocations: const Value('["Detroit, MI"]'),
    );

    final fuel = FuelEntriesCompanion.insert(
      id: 'fuel-1',
      userId: const Value('test-user'),
      fuelDate: DateTime(2023, 10, 2),
      fuelQuantity: 50.0,
      pricePerUnit: 4.0,
      location: const Value('Gary, IN'),
      fuelType: const Value('truck'),
      truckNumber: const Value('T-100'),
    );

    await driverDatabase.into(driverDatabase.trips).insert(trip);
    await driverDatabase.into(driverDatabase.fuelEntries).insert(fuel);

    await pumpPage(tester);

    // Verify Trip Card
    expect(find.text('Trip #12345'), findsOneWidget);
    // AddressUtils.extractCityState removes comma from "City, ST" format
    expect(find.text('Chicago IL → Detroit MI'), findsOneWidget);

    // Verify Fuel Card
    expect(find.text('Truck - T-100'), findsOneWidget);
    // AddressUtils.extractCityState removes comma from "City, ST" format
    expect(find.text('Gary IN'), findsOneWidget);
  });

  testWidgets('filters functionality works', (tester) async {
    // Seed Trips and Fuel
    final trip = TripsCompanion.insert(
      id: 'trip-1',
      userId: const Value('test-user'),
      tripNumber: '100',
      truckNumber: 'T-100',
      tripDate: DateTime.now(),
    );

    final fuel = FuelEntriesCompanion.insert(
      id: 'fuel-1',
      userId: const Value('test-user'),
      fuelDate: DateTime.now(),
      fuelQuantity: 10.0,
      pricePerUnit: 1.0,
      fuelType: const Value('truck'),
      truckNumber: const Value(
        'Truck',
      ), // Default identifier logic uses truckNumber or "Truck"
    );

    await driverDatabase.into(driverDatabase.trips).insert(trip);
    await driverDatabase.into(driverDatabase.fuelEntries).insert(fuel);

    await pumpPage(tester);

    // Initial: Show All
    expect(find.text('Trip #100'), findsOneWidget);
    // Fuel entry has truckNumber 'Truck'
    expect(find.text('Truck - Truck'), findsOneWidget);

    // Filter: Trips Only
    await tester.tap(find.text('Trips Only'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Trip #100'), findsOneWidget);
    expect(find.text('Truck - Truck'), findsNothing);

    // Filter: Fuel Only
    await tester.tap(find.text('Fuel Only'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Trip #100'), findsNothing);
    expect(find.text('Truck - Truck'), findsOneWidget);
  });

  testWidgets('search functionality works', (tester) async {
    final trip1 = TripsCompanion.insert(
      id: 't1',
      userId: const Value('test-user'),
      tripNumber: 'ALPHA',
      truckNumber: 'T-1',
      tripDate: DateTime.now(),
    );
    final trip2 = TripsCompanion.insert(
      id: 't2',
      userId: const Value('test-user'),
      tripNumber: 'BETA',
      truckNumber: 'T-2',
      tripDate: DateTime.now(),
    );

    await driverDatabase.into(driverDatabase.trips).insert(trip1);
    await driverDatabase.into(driverDatabase.trips).insert(trip2);

    await pumpPage(tester);

    expect(find.text('Trip #ALPHA'), findsOneWidget);
    expect(find.text('Trip #BETA'), findsOneWidget);

    // Open Search (Icon in AppBar actions)
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Enter Query
    await tester.enterText(find.byType(TextField), 'ALPHA');
    await tester.pump(
      const Duration(milliseconds: 300),
    ); // Allow debounce/state update

    expect(find.text('Trip #ALPHA'), findsOneWidget);
    expect(find.text('Trip #BETA'), findsNothing);

    // Clear Match
    await tester.enterText(find.byType(TextField), 'ZETA');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Trip #ALPHA'), findsNothing);
    expect(find.text('No matching records'), findsOneWidget);
  });
}
