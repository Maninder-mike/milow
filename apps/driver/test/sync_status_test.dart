import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/models/sync_status.dart';

void main() {
  group('SyncStatusInfo', () {
    test('synced factory creates correct instance', () {
      final status = SyncStatusInfo.synced();

      expect(status.status, SyncStatus.synced);
      expect(status.pendingCount, 0);
      expect(status.failedCount, 0);
      expect(status.message, isNull);
    });

    test('offline factory creates correct instance', () {
      final status = SyncStatusInfo.offline();

      expect(status.status, SyncStatus.offline);
      expect(status.pendingCount, 0);
    });

    test('pending factory tracks count', () {
      final status = SyncStatusInfo.pending(7);

      expect(status.status, SyncStatus.pending);
      expect(status.pendingCount, 7);
    });

    test('syncing factory tracks count', () {
      final status = SyncStatusInfo.syncing(3);

      expect(status.status, SyncStatus.syncing);
      expect(status.pendingCount, 3);
    });

    test('error factory includes message and count', () {
      final status = SyncStatusInfo.error(2, 'Connection failed');

      expect(status.status, SyncStatus.error);
      expect(status.failedCount, 2);
      expect(status.message, 'Connection failed');
    });

    test('toString provides readable output', () {
      final status = SyncStatusInfo(
        status: SyncStatus.pending,
        pendingCount: 5,
        failedCount: 1,
      );

      expect(status.toString(), contains('pending'));
      expect(status.toString(), contains('5'));
    });
  });

  group('SyncStatus enum', () {
    test('has all expected values', () {
      expect(SyncStatus.values.length, 5);
      expect(
        SyncStatus.values,
        containsAll([
          SyncStatus.synced,
          SyncStatus.pending,
          SyncStatus.syncing,
          SyncStatus.offline,
          SyncStatus.error,
        ]),
      );
    });
  });
}
