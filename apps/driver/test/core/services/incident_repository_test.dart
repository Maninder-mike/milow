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
import 'package:milow/core/services/incident_repository.dart';
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

void main() {
  late Directory tempDir;
  late MockConnectivityService mockConnectivityService;
  late MockSupabaseClient mockSupabaseClient;
  late StreamController<bool> connectivityController;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('incident_repo_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    ConnectivityPlatform.instance = FakeConnectivity();
    await Hive.initFlutter(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      try {
        Hive.registerAdapter(SyncOperationAdapter());
      } catch (_) {}
    }

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

    if (!Hive.isBoxOpen('sync_queue')) {
      await SyncQueueService.instance.init();
    }
    await Hive.box<SyncOperation>('sync_queue').clear();

    await driverDatabase.delete(driverDatabase.incidents).go();
  });

  group('IncidentRepository Tests', () {
    final testIncident = Incident(
      id: 'incident-123',
      userId: 'test_user_id',
      incidentDate: DateTime(2026, 6, 2, 10, 30),
      description: 'Minor fender bender at warehouse',
      location: '123 Main St',
      thirdPartyInfo: {
        'name': 'John Doe',
        'phone': '555-0199',
      },
      photos: ['/temp/photo1.jpg'],
      createdAt: DateTime(2026, 6, 2),
      updatedAt: DateTime(2026, 6, 2),
    );

    test('createIncident saves locally and enqueues sync', () async {
      final result = await IncidentRepository.createIncident(
        testIncident,
        supabaseClient: mockSupabaseClient,
      );
      final incident = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(incident.description, testIncident.description);
      expect(incident.location, testIncident.location);

      final dbIncidents = await driverDatabase.select(driverDatabase.incidents).get();
      expect(dbIncidents.length, 1);
      expect(dbIncidents.first.id, incident.id);
      expect(dbIncidents.first.description, testIncident.description);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'incidents');
      expect(pendingOps.first.operationType, 'create');
      expect(pendingOps.first.localId, incident.id);
    });

    test('updateIncident updates locally and enqueues sync', () async {
      await IncidentRepository.createIncident(
        testIncident,
        supabaseClient: mockSupabaseClient,
      );

      final updatedIncident = testIncident.copyWith(description: 'Updated fender bender');
      final result = await IncidentRepository.updateIncident(
        updatedIncident,
        supabaseClient: mockSupabaseClient,
      );
      final incident = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(incident.description, 'Updated fender bender');

      final dbIncidents = await driverDatabase.select(driverDatabase.incidents).get();
      expect(dbIncidents.first.description, 'Updated fender bender');

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'incidents');
      expect(pendingOps.first.operationType, 'update');
    });

    test('deleteIncident soft deletes locally and enqueues sync', () async {
      await IncidentRepository.createIncident(
        testIncident,
        supabaseClient: mockSupabaseClient,
      );

      final result = await IncidentRepository.deleteIncident(
        testIncident.id,
        supabaseClient: mockSupabaseClient,
      );
      expect(result.isRight(), true);

      final dbIncidents = await driverDatabase.select(driverDatabase.incidents).get();
      expect(dbIncidents.first.isDeleted, true);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'incidents');
      expect(pendingOps.first.operationType, 'update');
    });
  });
}
