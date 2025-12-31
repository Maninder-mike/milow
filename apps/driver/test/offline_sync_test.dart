import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/models/sync_operation.dart';
import 'package:milow/core/models/sync_status.dart';

/// Mock connectivity service for testing
class MockConnectivityService {
  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  void dispose() {
    _controller.close();
  }
}

/// Mock sync queue for testing without Supabase
class MockSyncQueue {
  final List<SyncOperation> _queue = [];
  final _statusController = StreamController<SyncStatusInfo>.broadcast();
  final MockConnectivityService _connectivity;
  bool _disposed = false;

  MockSyncQueue(this._connectivity);

  Stream<SyncStatusInfo> get syncStatus => _statusController.stream;
  int get pendingCount => _queue.where((op) => op.status == 'pending').length;
  int get failedCount => _queue.where((op) => op.status == 'failed').length;
  List<SyncOperation> get operations => List.unmodifiable(_queue);

  String enqueue({
    required String tableName,
    required String operationType,
    required Map<String, dynamic> payload,
    required String localId,
  }) {
    final id = 'mock-${DateTime.now().millisecondsSinceEpoch}';

    final operation = SyncOperation(
      id: id,
      tableName: tableName,
      operationType: operationType,
      payload: json.encode(payload),
      createdAt: DateTime.now(),
      localId: localId,
    );

    _queue.add(operation);
    _emitStatus();

    if (_connectivity.isOnline) {
      // Simulate immediate processing when online
      Future.delayed(const Duration(milliseconds: 10), () => _processNext());
    }

    return id;
  }

  void _processNext() {
    if (_disposed) return;

    final pending = _queue.where((op) => op.status == 'pending').toList();
    if (pending.isEmpty) return;

    final op = pending.first;
    op.status = 'syncing';
    _safeEmit(SyncStatusInfo.syncing(pendingCount));

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_disposed) return;
      // Simulate success
      op.status = 'completed';
      _queue.remove(op);
      _emitStatus();
    });
  }

  void processQueue() {
    if (!_connectivity.isOnline) return;
    _processNext();
  }

  void _safeEmit(SyncStatusInfo status) {
    if (!_disposed) {
      _statusController.add(status);
    }
  }

  void _emitStatus() {
    if (_disposed) return;

    if (!_connectivity.isOnline) {
      _safeEmit(SyncStatusInfo.offline());
    } else if (failedCount > 0) {
      _safeEmit(SyncStatusInfo.error(failedCount, 'Some operations failed'));
    } else if (pendingCount > 0) {
      _safeEmit(SyncStatusInfo.pending(pendingCount));
    } else {
      _safeEmit(SyncStatusInfo.synced());
    }
  }

  void dispose() {
    _disposed = true;
    _statusController.close();
  }
}

/// Mock local store using in-memory map
class MockLocalStore<T> {
  final Map<String, T> _store = {};

  T? get(String id) => _store[id];

  void put(String id, T value) => _store[id] = value;

  void delete(String id) => _store.remove(id);

  List<T> getAll() => _store.values.toList();

  void clear() => _store.clear();

  int get length => _store.length;
}

void main() {
  group('MockConnectivityService', () {
    late MockConnectivityService connectivity;

    setUp(() {
      connectivity = MockConnectivityService();
    });

    tearDown(() {
      connectivity.dispose();
    });

    test('starts online by default', () {
      expect(connectivity.isOnline, isTrue);
    });

    test('emits events on connectivity change', () async {
      final events = <bool>[];
      final sub = connectivity.onConnectivityChanged.listen(events.add);

      connectivity.setOnline(false);
      connectivity.setOnline(true);
      connectivity.setOnline(false);

      // Give time for events to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, [false, true, false]);

      await sub.cancel();
    });

    test('does not emit duplicate events', () async {
      final events = <bool>[];
      final sub = connectivity.onConnectivityChanged.listen(events.add);

      connectivity.setOnline(false);
      connectivity.setOnline(false); // Duplicate
      connectivity.setOnline(false); // Duplicate

      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, [false]); // Only one event

      await sub.cancel();
    });
  });

  group('MockSyncQueue', () {
    late MockConnectivityService connectivity;
    late MockSyncQueue syncQueue;

    setUp(() {
      connectivity = MockConnectivityService();
      syncQueue = MockSyncQueue(connectivity);
    });

    tearDown(() {
      syncQueue.dispose();
      connectivity.dispose();
    });

    test('enqueues operations', () {
      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'create',
        payload: {'trip_number': 'T-001'},
        localId: 'local-1',
      );

      expect(syncQueue.operations.length, 1);
      expect(syncQueue.pendingCount, 1);
    });

    test('processes queue when online', () async {
      // Start offline
      connectivity.setOnline(false);

      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'create',
        payload: {'trip_number': 'T-001'},
        localId: 'local-1',
      );

      expect(syncQueue.pendingCount, 1);

      // Go online
      connectivity.setOnline(true);
      syncQueue.processQueue();

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));

      expect(syncQueue.pendingCount, 0);
    });

    test('emits correct status events', () async {
      final statuses = <SyncStatus>[];
      final sub = syncQueue.syncStatus.listen(
        (info) => statuses.add(info.status),
      );

      // Go offline
      connectivity.setOnline(false);

      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'create',
        payload: {'trip_number': 'T-001'},
        localId: 'local-1',
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // Should emit offline status
      expect(statuses, contains(SyncStatus.offline));

      await sub.cancel();
    });
  });

  group('MockLocalStore', () {
    late MockLocalStore<Map<String, dynamic>> store;

    setUp(() {
      store = MockLocalStore<Map<String, dynamic>>();
    });

    test('stores and retrieves values', () {
      final trip = {'id': '1', 'name': 'Trip 1'};

      store.put('1', trip);

      expect(store.get('1'), trip);
    });

    test('returns null for missing keys', () {
      expect(store.get('nonexistent'), isNull);
    });

    test('deletes values', () {
      store.put('1', {'id': '1'});
      store.delete('1');

      expect(store.get('1'), isNull);
    });

    test('clears all values', () {
      store.put('1', {'id': '1'});
      store.put('2', {'id': '2'});
      store.put('3', {'id': '3'});

      expect(store.length, 3);

      store.clear();

      expect(store.length, 0);
    });

    test('getAll returns all values', () {
      store.put('1', {'id': '1'});
      store.put('2', {'id': '2'});

      final all = store.getAll();

      expect(all.length, 2);
    });
  });

  group('Offline-first pattern integration', () {
    late MockConnectivityService connectivity;
    late MockSyncQueue syncQueue;
    late MockLocalStore<Map<String, dynamic>> localStore;

    setUp(() {
      connectivity = MockConnectivityService();
      syncQueue = MockSyncQueue(connectivity);
      localStore = MockLocalStore<Map<String, dynamic>>();
    });

    tearDown(() {
      syncQueue.dispose();
      connectivity.dispose();
    });

    test('create operation: saves locally and queues sync', () async {
      connectivity.setOnline(false);

      final tripData = {
        'id': 'local-1',
        'trip_number': 'T-001',
        'origin': 'LA',
        'destination': 'Phoenix',
      };

      // Simulate repository create
      localStore.put(tripData['id'] as String, tripData);
      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'create',
        payload: tripData,
        localId: tripData['id'] as String,
      );

      // Data should be immediately available locally
      expect(localStore.get('local-1'), isNotNull);
      expect(localStore.get('local-1')!['trip_number'], 'T-001');

      // Sync should be pending
      expect(syncQueue.pendingCount, 1);
    });

    test('update operation: updates locally and queues sync', () async {
      connectivity.setOnline(false);

      // Initial data
      localStore.put('trip-1', {
        'id': 'trip-1',
        'trip_number': 'T-001',
        'origin': 'LA',
      });

      // Update
      final updated = {
        'id': 'trip-1',
        'trip_number': 'T-001',
        'origin': 'San Diego', // Changed
      };

      localStore.put('trip-1', updated);
      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'update',
        payload: updated,
        localId: 'trip-1',
      );

      // Verify update is reflected locally
      expect(localStore.get('trip-1')!['origin'], 'San Diego');
      expect(syncQueue.pendingCount, 1);
    });

    test('delete operation: removes locally and queues sync', () async {
      connectivity.setOnline(false);

      // Initial data
      localStore.put('trip-1', {'id': 'trip-1', 'trip_number': 'T-001'});
      expect(localStore.get('trip-1'), isNotNull);

      // Delete
      localStore.delete('trip-1');
      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'delete',
        payload: {'id': 'trip-1'},
        localId: 'trip-1',
      );

      // Verify deleted locally
      expect(localStore.get('trip-1'), isNull);
      expect(syncQueue.pendingCount, 1);
    });

    test('sync completes when going online', () async {
      // Start offline
      connectivity.setOnline(false);

      // Create operation while offline
      localStore.put('local-1', {'id': 'local-1', 'trip_number': 'T-001'});
      syncQueue.enqueue(
        tableName: 'trips',
        operationType: 'create',
        payload: {'id': 'local-1', 'trip_number': 'T-001'},
        localId: 'local-1',
      );

      expect(syncQueue.pendingCount, 1);

      // Go online
      connectivity.setOnline(true);
      syncQueue.processQueue();

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Sync should complete
      expect(syncQueue.pendingCount, 0);
    });

    test('multiple operations queue correctly', () async {
      connectivity.setOnline(false);

      // Multiple creates
      for (var i = 1; i <= 5; i++) {
        localStore.put('trip-$i', {'id': 'trip-$i', 'number': 'T-00$i'});
        syncQueue.enqueue(
          tableName: 'trips',
          operationType: 'create',
          payload: {'id': 'trip-$i', 'number': 'T-00$i'},
          localId: 'trip-$i',
        );
      }

      expect(localStore.length, 5);
      expect(syncQueue.pendingCount, 5);
    });
  });
}
