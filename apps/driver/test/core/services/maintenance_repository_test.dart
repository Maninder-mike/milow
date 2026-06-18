import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:drift/drift.dart' hide Column;

import 'package:milow/core/models/sync_operation.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/maintenance_repository.dart';
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
    tempDir = await Directory.systemTemp.createTemp('maintenance_repo_test_');
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

    await driverDatabase.delete(driverDatabase.vehicles).go();
    await driverDatabase.delete(driverDatabase.maintenanceSchedules).go();
    await driverDatabase.delete(driverDatabase.maintenanceRecords).go();
  });

  group('MaintenanceRepository Tests', () {
    const testVehicle = Vehicle(
      id: 'vehicle-123',
      truckNumber: 'TRK-100',
      vehicleType: 'semi-truck',
    );

    final testSchedule = MaintenanceSchedule(
      id: 'schedule-123',
      vehicleId: 'vehicle-123',
      serviceType: MaintenanceServiceType.oilChange,
      intervalMiles: 15000,
      intervalDays: 180,
      lastPerformedAt: DateTime(2026, 1, 1),
      lastOdometer: 100000,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final testRecord = MaintenanceRecord(
      id: 'record-123',
      vehicleId: 'vehicle-123',
      serviceType: MaintenanceServiceType.oilChange,
      description: 'Regular engine oil change',
      odometerAtService: 115000,
      cost: 350.0,
      performedBy: 'Speedy Lube',
      performedAt: DateTime(2026, 6, 2),
      nextDueOdometer: 130000,
      nextDueDate: DateTime(2026, 12, 2),
      notes: 'No issues found during check.',
      createdAt: DateTime(2026, 6, 2),
    );

    test('getVehicles returns cached vehicles', () async {
      await driverDatabase.into(driverDatabase.vehicles).insert(
        VehiclesCompanion.insert(
          id: testVehicle.id,
          companyId: 'company-123',
          truckNumber: testVehicle.truckNumber,
          vehicleType: testVehicle.vehicleType ?? 'truck',
          vinNumber: 'vin-123',
        ),
      );

      final result = await MaintenanceRepository.getVehicles(
        refresh: false,
        supabaseClient: mockSupabaseClient,
      );
      final vehicles = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(vehicles.length, 1);
      expect(vehicles.first.id, testVehicle.id);
      expect(vehicles.first.truckNumber, testVehicle.truckNumber);
    });

    test('getSchedules returns cached schedules', () async {
      await driverDatabase.into(driverDatabase.maintenanceSchedules).insert(
        MaintenanceSchedulesCompanion.insert(
          id: testSchedule.id,
          vehicleId: testSchedule.vehicleId,
          serviceType: testSchedule.serviceType.name,
          intervalMiles: Value(testSchedule.intervalMiles),
          intervalDays: Value(testSchedule.intervalDays),
          lastPerformedAt: Value(testSchedule.lastPerformedAt),
          lastOdometer: Value(testSchedule.lastOdometer),
          isActive: Value(testSchedule.isActive),
          createdAt: Value(testSchedule.createdAt),
        ),
      );

      final result = await MaintenanceRepository.getSchedules(
        testSchedule.vehicleId,
        refresh: false,
        supabaseClient: mockSupabaseClient,
      );
      final schedules = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(schedules.length, 1);
      expect(schedules.first.id, testSchedule.id);
      expect(schedules.first.serviceType, testSchedule.serviceType);
    });

    test('createRecord saves record, updates schedule last performed, and enqueues sync', () async {
      await driverDatabase.into(driverDatabase.maintenanceSchedules).insert(
        MaintenanceSchedulesCompanion.insert(
          id: testSchedule.id,
          vehicleId: testSchedule.vehicleId,
          serviceType: testSchedule.serviceType.name,
          intervalMiles: Value(testSchedule.intervalMiles),
          intervalDays: Value(testSchedule.intervalDays),
          lastPerformedAt: Value(testSchedule.lastPerformedAt),
          lastOdometer: Value(testSchedule.lastOdometer),
          isActive: Value(testSchedule.isActive),
          createdAt: Value(testSchedule.createdAt),
        ),
      );

      final result = await MaintenanceRepository.createRecord(
        testRecord,
        supabaseClient: mockSupabaseClient,
      );
      final record = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(record.description, testRecord.description);
      expect(record.cost, testRecord.cost);

      final dbRecords = await driverDatabase.select(driverDatabase.maintenanceRecords).get();
      expect(dbRecords.length, 1);
      expect(dbRecords.first.id, record.id);

      final dbSchedules = await driverDatabase.select(driverDatabase.maintenanceSchedules).get();
      expect(dbSchedules.first.lastOdometer, testRecord.odometerAtService);
      expect(dbSchedules.first.lastPerformedAt, testRecord.performedAt);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'maintenance_records');
      expect(pendingOps.first.operationType, 'create');
    });

    test('deleteRecord soft deletes record and enqueues sync', () async {
      await driverDatabase.into(driverDatabase.maintenanceRecords).insert(
        MaintenanceRecordsCompanion.insert(
          id: testRecord.id,
          vehicleId: testRecord.vehicleId,
          serviceType: testRecord.serviceType.name,
          description: Value(testRecord.description),
          odometerAtService: Value(testRecord.odometerAtService),
          cost: Value(testRecord.cost),
          performedBy: Value(testRecord.performedBy),
          performedAt: testRecord.performedAt,
          notes: Value(testRecord.notes),
          isSynced: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      final result = await MaintenanceRepository.deleteRecord(
        testRecord.id,
        supabaseClient: mockSupabaseClient,
      );
      expect(result.isRight(), true);

      final dbRecords = await driverDatabase.select(driverDatabase.maintenanceRecords).get();
      expect(dbRecords.first.isDeleted, true);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'maintenance_records');
      expect(pendingOps.first.operationType, 'update');
    });
  });
}
