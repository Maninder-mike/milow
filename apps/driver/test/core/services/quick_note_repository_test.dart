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
import 'package:milow/core/services/quick_note_repository.dart';
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
    tempDir = await Directory.systemTemp.createTemp('quick_note_repo_test_');
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

    await driverDatabase.delete(driverDatabase.quickNotes).go();
  });

  group('QuickNoteRepository Tests', () {
    final testNote = QuickNote(
      id: 'note-123',
      userId: 'test_user_id',
      title: 'Test Note',
      content: 'This is a test note content.',
      createdAt: DateTime(2026, 6, 2),
      updatedAt: DateTime(2026, 6, 2),
    );

    test('createQuickNote saves locally and enqueues sync', () async {
      final result = await QuickNoteRepository.createQuickNote(
        testNote,
        supabaseClient: mockSupabaseClient,
      );
      final note = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(note.title, testNote.title);
      expect(note.content, testNote.content);

      final dbNotes = await driverDatabase.select(driverDatabase.quickNotes).get();
      expect(dbNotes.length, 1);
      expect(dbNotes.first.id, note.id);
      expect(dbNotes.first.title, testNote.title);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'quick_notes');
      expect(pendingOps.first.operationType, 'create');
      expect(pendingOps.first.localId, note.id);
    });

    test('updateQuickNote updates locally and enqueues sync', () async {
      await driverDatabase.into(driverDatabase.quickNotes).insert(
        QuickNotesCompanion.insert(
          id: testNote.id,
          userId: testNote.userId ?? 'test_user_id',
          title: Value(testNote.title),
          content: Value(testNote.content),
          createdAt: Value(testNote.createdAt),
          updatedAt: Value(testNote.updatedAt),
          isSynced: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      final updatedNote = testNote.copyWith(content: 'Updated content');
      final result = await QuickNoteRepository.updateQuickNote(
        updatedNote,
        supabaseClient: mockSupabaseClient,
      );
      final note = result.fold((l) => throw Exception(l.message), (r) => r);

      expect(note.content, 'Updated content');

      final dbNotes = await driverDatabase.select(driverDatabase.quickNotes).get();
      expect(dbNotes.first.content, 'Updated content');

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'quick_notes');
      expect(pendingOps.first.operationType, 'update');
    });

    test('deleteQuickNote soft deletes locally and enqueues sync', () async {
      await driverDatabase.into(driverDatabase.quickNotes).insert(
        QuickNotesCompanion.insert(
          id: testNote.id,
          userId: testNote.userId ?? 'test_user_id',
          title: Value(testNote.title),
          content: Value(testNote.content),
          createdAt: Value(testNote.createdAt),
          updatedAt: Value(testNote.updatedAt),
          isSynced: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      final result = await QuickNoteRepository.deleteQuickNote(
        testNote.id,
        supabaseClient: mockSupabaseClient,
      );
      expect(result.isRight(), true);

      final dbNotes = await driverDatabase.select(driverDatabase.quickNotes).get();
      expect(dbNotes.first.isDeleted, true);

      final pendingOps = syncQueueService.pendingOperations;
      expect(pendingOps.length, 1);
      expect(pendingOps.first.tableName, 'quick_notes');
      expect(pendingOps.first.operationType, 'update');
    });
  });
}
