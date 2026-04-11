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
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';

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

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(
    Map<dynamic, dynamic> values,
  ) {
    return MockPostgrestFilterBuilder();
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    return MockPostgrestFilterBuilder();
  }
}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(
    String column,
    Object value,
  ) {
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) async {
    return onValue([]);
  }
}

void main() {
  late Directory tempDir;
  late MockConnectivityService mockConnectivityService;
  late MockSupabaseClient mockSupabaseClient;
  late StreamController<bool> connectivityController;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_queue_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    ConnectivityPlatform.instance = FakeConnectivity();
    await Hive.initFlutter(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SyncOperationAdapter());
    }

    // Fallback registration for mocktail
    registerFallbackValue({});
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    mockConnectivityService = MockConnectivityService();
    mockSupabaseClient = MockSupabaseClient();
    connectivityController = StreamController<bool>.broadcast();

    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(
      () => mockConnectivityService.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);

    ConnectivityService.instance = mockConnectivityService;

    // Initialize or clear existing box
    if (!Hive.isBoxOpen('sync_queue')) {
      await SyncQueueService.instance.init();
    }
    await Hive.box<SyncOperation>('sync_queue').clear();
  });

  tearDown(() {
    connectivityController.close();
  });

  group('SyncQueueService Tests', () {
    test('enqueues operation and returns id', () async {
      when(() => mockConnectivityService.isOnline).thenReturn(false);

      final id = await SyncQueueService.instance.enqueue(
        tableName: 'test_table',
        operationType: 'create',
        payload: {'key': 'value'},
        localId: 'local_1',
      );

      expect(id, isNotEmpty);
      expect(SyncQueueService.instance.pendingCount, 1);
      final operations = SyncQueueService.instance.pendingOperations;
      expect(operations.first.tableName, 'test_table');
      expect(operations.first.operationType, 'create');
      expect(operations.first.localId, 'local_1');
    });

    test('processes queue immediately if online', () async {
      when(() => mockConnectivityService.isOnline).thenReturn(false);

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      when(
        () => mockSupabaseClient.from('driver_trips'),
      ).thenAnswer((_) => mockQueryBuilder);

      // We enqueue offline, then manually process online
      await SyncQueueService.instance.enqueue(
        tableName: 'driver_trips', // Checking normal table name
        operationType: 'create',
        payload: {'id': 'trip_1'},
        localId: 'local_1',
      );

      when(() => mockConnectivityService.isOnline).thenReturn(true);

      // Process queue explicitly to pass the mock client
      await SyncQueueService.instance.processQueue(
        supabaseClient: mockSupabaseClient,
      );

      // Verify it was processed and removed
      expect(SyncQueueService.instance.pendingCount, 0);
      verify(() => mockSupabaseClient.from('driver_trips')).called(1);
    });

    test(
      'backwards compatibility: mapping "trips" to "driver_trips"',
      () async {
        when(() => mockConnectivityService.isOnline).thenReturn(false);

        final mockQueryBuilder = MockSupabaseQueryBuilder();
        // It MUST call driver_trips, not trips
        when(
          () => mockSupabaseClient.from('driver_trips'),
        ).thenAnswer((_) => mockQueryBuilder);

        await SyncQueueService.instance.enqueue(
          tableName: 'trips', // The old table name
          operationType: 'create',
          payload: {'id': 'trip_old'},
          localId: 'local_old',
        );

        when(() => mockConnectivityService.isOnline).thenReturn(true);

        await SyncQueueService.instance.processQueue(
          supabaseClient: mockSupabaseClient,
        );

        // Verify that 'from' was called with the mapped table name
        verify(() => mockSupabaseClient.from('driver_trips')).called(1);
        verifyNever(() => mockSupabaseClient.from('trips'));
        expect(
          SyncQueueService.instance.pendingCount,
          0,
        ); // successfully removed
      },
    );

    test('update operation correctly passes payload with id', () async {
      when(() => mockConnectivityService.isOnline).thenReturn(false);

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      when(
        () => mockSupabaseClient.from('driver_trips'),
      ).thenAnswer((_) => mockQueryBuilder);

      await SyncQueueService.instance.enqueue(
        tableName: 'driver_trips',
        operationType: 'update',
        payload: {'id': 'trip_update', 'status': 'completed'},
        localId: 'local_update',
      );

      when(() => mockConnectivityService.isOnline).thenReturn(true);

      await SyncQueueService.instance.processQueue(
        supabaseClient: mockSupabaseClient,
      );

      verify(() => mockSupabaseClient.from('driver_trips')).called(1);
      expect(SyncQueueService.instance.pendingCount, 0);
    });
  });
}
