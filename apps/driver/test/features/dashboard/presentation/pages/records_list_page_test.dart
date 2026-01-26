import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/local_fuel_store.dart';
import 'package:milow/core/services/local_trip_store.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow_core/milow_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock Connectivity Service
class MockConnectivityService extends ConnectivityService {
  MockConnectivityService() : super.testing();

  @override
  bool get isOnline => false; // Force offline to use local stores

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(false);
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Setup Hive for testing
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);

    // Open boxes if not already open
    if (!Hive.isBoxOpen('trips')) {
      await Hive.openBox<String>('trips');
    }
    if (!Hive.isBoxOpen('fuel_entries')) {
      await Hive.openBox<String>('fuel_entries');
    }

    // Initialize Local Stores
    // Just ensure the boxes are open, LocalTripStore.init() expects Hive to be init
    // LocalTripStore._box = await Hive.openBox(...) in actual code
    // We can manually inject the box if needed, or call init()
    // But init() calls Hive.openBox which works if Hive.init is called.
    await LocalTripStore.init();
    await LocalFuelStore.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // Inject Mock Connectivity
    ConnectivityService.instance = MockConnectivityService();

    // Inject Mock User ID
    TripRepository.mockUserId = 'test-user';
    FuelRepository.mockUserId = 'test-user';

    // Clear stores
    await LocalTripStore.clear();
    await LocalFuelStore.clear();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [DesignTokens.light]),
        home: const RecordsListPage(),
      ),
    );
    // Trigger initState and first frame
    await tester.pump();
    // Allow futures in _loadRecords to complete
    await tester.pump(const Duration(milliseconds: 100));
    // Rebuild with new state
    await tester.pump();
  }

  testWidgets('renders successfully with empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text('All Records'), findsOneWidget);
    expect(
      find.byType(SliverAppBar),
      findsWidgets,
    ); // 1 or 2 depending on implementation
    expect(find.text('No matching records'), findsOneWidget);
  });

  testWidgets('loads and displays trips and fuel', (tester) async {
    // Seed Data
    final trip = Trip(
      id: 'trip-1',
      userId: 'test-user',
      tripNumber: '12345',
      tripDate: DateTime(2023, 10, 1),
      truckNumber: 'T-100',
      pickupLocations: ['Chicago, IL'],
      deliveryLocations: ['Detroit, MI'],
    );

    final fuel = FuelEntry(
      id: 'fuel-1',
      userId: 'test-user',
      fuelDate: DateTime(2023, 10, 2),
      fuelQuantity: 50.0,
      fuelUnit: 'gal',
      pricePerUnit: 4.0, // results in 200.0 cost
      currency: 'USD',
      location: 'Gary, IN',
      fuelType: 'truck',
      truckNumber: 'T-100',
    );

    await LocalTripStore.put(trip);
    await LocalFuelStore.put(fuel);

    await pumpPage(tester);

    // Verify Trip Card
    expect(find.text('Trip #12345'), findsOneWidget);
    expect(find.text('Chicago, IL → Detroit, MI'), findsOneWidget);

    // Verify Fuel Card
    expect(find.text('Truck - T-100'), findsOneWidget);
    expect(find.text('Gary, IN'), findsOneWidget);
  });

  testWidgets('filters functionality works', (tester) async {
    // Seed Trips and Fuel
    final trip = Trip(
      id: 'trip-1',
      userId: 'test-user',
      tripNumber: '100',
      tripDate: DateTime.now(),
      truckNumber: 'T-100', // Required
      pickupLocations: [],
      deliveryLocations: [],
    );
    final fuel = FuelEntry(
      id: 'fuel-1',
      userId: 'test-user',
      fuelDate: DateTime.now(),
      fuelQuantity: 10,
      fuelUnit: 'gal',
      pricePerUnit: 1.0,
      currency: 'USD',
      fuelType: 'truck',
    );

    await LocalTripStore.put(trip);
    await LocalFuelStore.put(fuel);

    await pumpPage(tester);

    // Initial: Show All
    expect(find.text('Trip #100'), findsOneWidget);
    expect(find.text('Truck - T-100'), findsOneWidget); // Identifier fallback

    // Filter: Trips Only
    await tester.tap(find.text('Trips Only'));
    await tester.pumpAndSettle();

    expect(find.text('Trip #100'), findsOneWidget);
    expect(find.text('Truck - T-100'), findsNothing);

    // Filter: Fuel Only
    await tester.tap(find.text('Fuel Only'));
    await tester.pumpAndSettle();

    expect(find.text('Trip #100'), findsNothing);
    expect(find.text('Truck - T-100'), findsOneWidget);
  });

  testWidgets('search functionality works', (tester) async {
    final trip1 = Trip(
      id: 't1',
      userId: 'test-user',
      tripNumber: 'ALPHA',
      tripDate: DateTime.now(),
      truckNumber: 'T-1',
      pickupLocations: [],
      deliveryLocations: [],
    );
    final trip2 = Trip(
      id: 't2',
      userId: 'test-user',
      tripNumber: 'BETA',
      tripDate: DateTime.now(),
      truckNumber: 'T-2',
      pickupLocations: [],
      deliveryLocations: [],
    );

    await LocalTripStore.put(trip1);
    await LocalTripStore.put(trip2);

    await pumpPage(tester);

    expect(find.text('Trip #ALPHA'), findsOneWidget);
    expect(find.text('Trip #BETA'), findsOneWidget);

    // Open Search (Icon in AppBar actions)
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    // Enter Query
    await tester.enterText(find.byType(TextField), 'ALPHA');
    await tester.pumpAndSettle(); // Allow debounce/state update

    expect(find.text('Trip #ALPHA'), findsOneWidget);
    expect(find.text('Trip #BETA'), findsNothing);

    // Clear Match
    await tester.enterText(find.byType(TextField), 'ZETA');
    await tester.pumpAndSettle();

    expect(find.text('Trip #ALPHA'), findsNothing);
    expect(find.text('No matching records'), findsOneWidget);
  });
}
