import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:milow/core/models/sync_operation.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProvider(this.path);
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class FakeConnectivity extends Fake
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value([ConnectivityResult.wifi]);
}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSupabaseClient extends Mock implements SupabaseClient {
  @override
  MockGoTrueClient get auth => MockGoTrueClient();
}

class MockGoTrueClient extends Mock implements GoTrueClient {
  @override
  User? get currentUser => const User(
    id: 'test_user_id',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2025-01-01T00:00:00Z',
  );
}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

Type typeOf<X>() => X;

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {
  final Object? mockError;
  final T? mockData;
  MockPostgrestTransformBuilder({this.mockError, this.mockData});

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    Future<U> future;
    if (mockError != null) {
      future = Future<U>.error(mockError!);
    } else if (mockData != null) {
      future = Future<T>.value(mockData as T).then(onValue);
    } else if (T == typeOf<Map<String, dynamic>?>()) {
      future = Future<T>.value(null as T).then(onValue);
    } else {
      future = Future<U>.error(UnimplementedError('No mock data for $T'));
    }

    if (onError != null) {
      return future.catchError(onError);
    }
    return future;
  }
}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {
  final Object? mockError;
  final T? mockData;
  MockPostgrestFilterBuilder({this.mockError, this.mockData});

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    Future<U> future;
    if (mockError != null) {
      future = Future<U>.error(mockError!);
    } else if (mockData != null) {
      future = Future<T>.value(mockData as T).then(onValue);
    } else if (T == typeOf<List<Map<String, dynamic>>>()) {
      future = Future<T>.value(<Map<String, dynamic>>[] as T).then(onValue);
    } else if (T == typeOf<Map<String, dynamic>?>()) {
      future = Future<T>.value(null as T).then(onValue);
    } else {
      future = Future<U>.error(UnimplementedError('No mock data for $T'));
    }

    if (onError != null) {
      return future.catchError(onError);
    }
    return future;
  }
}

void main() {
  late Directory tempDir;
  late MockConnectivityService mockConnectivityService;
  late MockSupabaseClient mockSupabaseClient;
  late StreamController<bool> connectivityController;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_repo_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    ConnectivityPlatform.instance = FakeConnectivity();
    await Hive.initFlutter(tempDir.path);
    Hive.registerAdapter(SyncOperationAdapter());

    // NOTE: DriverDatabase falls back to NativeDatabase.memory() by default in tests
    // due to the FLUTTER_TEST environment variable being checked in its constructor.
    mockConnectivityService = MockConnectivityService();
  });

  tearDownAll(() async {
    await driverDatabase.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    mockSupabaseClient = MockSupabaseClient();
    connectivityController = StreamController<bool>.broadcast();
    when(
      () => mockConnectivityService.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);
    when(() => mockConnectivityService.isOnline).thenReturn(false);

    ConnectivityService.instance = mockConnectivityService;

    // CoreNetworkClient uses network_cache box
    if (!Hive.isBoxOpen('network_cache')) {
      await Hive.openBox('network_cache');
    }

    if (!Hive.isBoxOpen('sync_queue')) {
      await SyncQueueService.instance.init();
    }
    await Hive.box<SyncOperation>('sync_queue').clear();

    // Clear the database
    await driverDatabase.delete(driverDatabase.trips).go();
  });

  group('TripRepository Tests', () {
    final testTrip = Trip(
      tripNumber: 'TRX-001',
      truckNumber: 'TRK-992',
      tripDate: DateTime(2025, 2, 28),
      pickupLocations: ['A'],
      deliveryLocations: ['B'],
      createdAt: DateTime(2025, 2, 28),
    );

    test('createTrip saves to local DB and enqueues sync', () async {
      final trip = await TripRepository.createTrip(
        testTrip,
        supabaseClient: mockSupabaseClient,
      );

      // Verify it generated an ID
      expect(trip.id, isNotNull);

      // Verify it was saved locally
      final dbTrips = await driverDatabase.select(driverDatabase.trips).get();
      expect(dbTrips.length, 1);
      expect(dbTrips.first.id, trip.id);
      expect(dbTrips.first.tripNumber, testTrip.tripNumber);

      // Verify it was enqueued
      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'driver_trips');
      expect(pendingOps.first.operationType, 'create');
      expect(pendingOps.first.localId, trip.id);
    });

    test('updateTrip saves to local DB and enqueues sync', () async {
      final trip = await TripRepository.createTrip(
        testTrip,
        supabaseClient: mockSupabaseClient,
      );

      final updatedTrip = trip.copyWith(notes: 'Updated note');

      await TripRepository.updateTrip(
        updatedTrip,
        supabaseClient: mockSupabaseClient,
      );

      // Verify it was updated locally
      final dbTrips = await driverDatabase.select(driverDatabase.trips).get();
      expect(dbTrips.length, 1);
      expect(dbTrips.first.notes, 'Updated note');

      // Verify the update action was enqueued
      final pendingOps = syncQueueService.pendingOperations
          .where((op) => op.operationType == 'update')
          .toList();
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'driver_trips');
      expect(pendingOps.first.localId, trip.id);
    });

    test('refresh from server respects LWW pending syncs', () async {
      when(() => mockConnectivityService.isOnline).thenReturn(false);

      // 1. Create a trip with pending 'update' locally
      final trip = await TripRepository.createTrip(
        testTrip,
        supabaseClient: mockSupabaseClient,
      );
      final updatedTrip = trip.copyWith(notes: 'Updated note');
      await TripRepository.updateTrip(
        updatedTrip,
        supabaseClient: mockSupabaseClient,
      );

      // 2. Mock Server response (Simulating an older state without our update)
      final serverTrip = trip.copyWith(notes: 'Old note');

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockFilterBuilderEq =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockTransformBuilder =
          MockPostgrestTransformBuilder<List<Map<String, dynamic>>>(
            mockData: [serverTrip.toJson()],
          );

      when(
        () => mockSupabaseClient.from('driver_trips'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.select(any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq(any(), any()),
      ).thenAnswer((_) => mockFilterBuilderEq);
      when(
        () => mockFilterBuilderEq.order(
          any(),
          ascending: any(named: 'ascending'),
        ),
      ).thenAnswer((_) => mockTransformBuilder);

      // 3. Call refresh
      await TripRepository.refresh(supabaseClient: mockSupabaseClient);

      // 4. Verify Local DB still has "Updated note"
      final dbTrips = await driverDatabase.select(driverDatabase.trips).get();
      expect(dbTrips.length, 1);
      expect(dbTrips.first.notes, 'Updated note');
    });
  });
}
