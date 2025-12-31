import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/models/sync_operation.dart';
import 'package:milow/core/models/sync_status.dart';

void main() {
  group('SyncOperation', () {
    test('creates with default values', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{"name": "test"}',
        createdAt: DateTime.now(),
        localId: 'local-id',
      );

      expect(op.status, 'pending');
      expect(op.retryCount, 0);
      expect(op.errorMessage, isNull);
      expect(op.canRetry, isTrue);
    });

    test('calculates backoff delay correctly', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
      );

      // Retry 0: 1s, Retry 1: 2s, Retry 2: 4s, etc.
      expect(op.backoffDelay, const Duration(seconds: 1));

      op.retryCount = 1;
      expect(op.backoffDelay, const Duration(seconds: 2));

      op.retryCount = 2;
      expect(op.backoffDelay, const Duration(seconds: 4));

      op.retryCount = 3;
      expect(op.backoffDelay, const Duration(seconds: 8));

      op.retryCount = 4;
      expect(op.backoffDelay, const Duration(seconds: 16));
    });

    test('canRetry returns false after max retries', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
        retryCount: SyncOperation.maxRetries,
      );

      expect(op.canRetry, isFalse);
    });

    test('canRetry returns false when completed', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
        status: 'completed',
      );

      expect(op.canRetry, isFalse);
    });

    test('toString returns readable format', () {
      final op = SyncOperation(
        id: 'abc123',
        tableName: 'fuel_entries',
        operationType: 'update',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
        status: 'syncing',
        retryCount: 2,
      );

      expect(
        op.toString(),
        'SyncOperation(id: abc123, table: fuel_entries, op: update, status: syncing, retries: 2)',
      );
    });
  });

  group('SyncStatus', () {
    test('enum has correct values', () {
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.syncing));
      expect(SyncStatus.values, contains(SyncStatus.offline));
      expect(SyncStatus.values, contains(SyncStatus.error));
    });
  });

  group('SyncStatusInfo', () {
    test('factory synced creates correct status', () {
      final info = SyncStatusInfo.synced();

      expect(info.status, SyncStatus.synced);
      expect(info.pendingCount, 0);
      expect(info.failedCount, 0);
      expect(info.message, isNull);
    });

    test('factory offline creates correct status', () {
      final info = SyncStatusInfo.offline();

      expect(info.status, SyncStatus.offline);
    });

    test('factory pending creates correct status with count', () {
      final info = SyncStatusInfo.pending(5);

      expect(info.status, SyncStatus.pending);
      expect(info.pendingCount, 5);
    });

    test('factory syncing creates correct status with count', () {
      final info = SyncStatusInfo.syncing(3);

      expect(info.status, SyncStatus.syncing);
      expect(info.pendingCount, 3);
    });

    test('factory error creates correct status with message', () {
      final info = SyncStatusInfo.error(2, 'Network error');

      expect(info.status, SyncStatus.error);
      expect(info.failedCount, 2);
      expect(info.message, 'Network error');
    });

    test('toString returns readable format', () {
      final info = SyncStatusInfo.pending(5);

      expect(
        info.toString(),
        'SyncStatusInfo(status: SyncStatus.pending, pending: 5, failed: 0)',
      );
    });
  });

  group('SyncOperation serialization', () {
    test('payload can store and retrieve JSON data', () {
      final tripData = {
        'trip_number': 'T-001',
        'origin': 'Los Angeles',
        'destination': 'Phoenix',
        'distance': 372.5,
      };

      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: json.encode(tripData),
        createdAt: DateTime.now(),
        localId: 'local-id',
      );

      final decoded = json.decode(op.payload) as Map<String, dynamic>;

      expect(decoded['trip_number'], 'T-001');
      expect(decoded['origin'], 'Los Angeles');
      expect(decoded['destination'], 'Phoenix');
      expect(decoded['distance'], 372.5);
    });

    test('handles complex nested payload', () {
      final payload = {
        'id': 'abc-123',
        'metadata': {
          'tags': ['urgent', 'priority'],
          'coordinates': {'lat': 34.0522, 'lng': -118.2437},
        },
      };

      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: json.encode(payload),
        createdAt: DateTime.now(),
        localId: 'local-id',
      );

      final decoded = json.decode(op.payload) as Map<String, dynamic>;
      final metadata = decoded['metadata'] as Map<String, dynamic>;
      final tags = metadata['tags'] as List<dynamic>;
      final coords = metadata['coordinates'] as Map<String, dynamic>;

      expect(tags, ['urgent', 'priority']);
      expect(coords['lat'], 34.0522);
    });
  });

  group('SyncOperation state transitions', () {
    test('transitions through expected states', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
      );

      // Initial state
      expect(op.status, 'pending');
      expect(op.retryCount, 0);

      // Simulate first sync attempt failure (without save() since not in box)
      op.status = 'syncing';
      expect(op.status, 'syncing');

      // Simulate failure
      op.status = 'failed';
      op.errorMessage = 'Network timeout';
      op.retryCount++;
      expect(op.status, 'failed');
      expect(op.retryCount, 1);
      expect(op.errorMessage, 'Network timeout');

      // Reset to pending for retry
      op.status = 'pending';
      expect(op.status, 'pending');
      expect(op.canRetry, isTrue);

      // Simulate successful sync
      op.status = 'completed';
      expect(op.status, 'completed');
      expect(op.canRetry, isFalse);
    });

    test('max retries reached stops retry attempts', () {
      final op = SyncOperation(
        id: 'test-id',
        tableName: 'trips',
        operationType: 'create',
        payload: '{}',
        createdAt: DateTime.now(),
        localId: 'local-id',
        retryCount: 4, // One below max
      );

      expect(op.canRetry, isTrue);

      op.retryCount = 5; // At max
      expect(op.canRetry, isFalse);
    });
  });
}
