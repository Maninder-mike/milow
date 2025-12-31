/// Status of the sync queue
enum SyncStatus {
  /// All operations synced, online
  synced,

  /// Has pending operations to sync
  pending,

  /// Currently syncing operations
  syncing,

  /// Device is offline
  offline,

  /// Some operations failed after max retries
  error,
}

/// Represents a sync status update with details
class SyncStatusInfo {
  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final String? message;

  const SyncStatusInfo({
    required this.status,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.message,
  });

  /// Quick factory for synced state
  factory SyncStatusInfo.synced() =>
      const SyncStatusInfo(status: SyncStatus.synced);

  /// Quick factory for offline state
  factory SyncStatusInfo.offline() =>
      const SyncStatusInfo(status: SyncStatus.offline);

  /// Quick factory for pending state
  factory SyncStatusInfo.pending(int count) =>
      SyncStatusInfo(status: SyncStatus.pending, pendingCount: count);

  /// Quick factory for syncing state
  factory SyncStatusInfo.syncing(int count) =>
      SyncStatusInfo(status: SyncStatus.syncing, pendingCount: count);

  /// Quick factory for error state
  factory SyncStatusInfo.error(int failedCount, String message) =>
      SyncStatusInfo(
        status: SyncStatus.error,
        failedCount: failedCount,
        message: message,
      );

  @override
  String toString() =>
      'SyncStatusInfo(status: $status, pending: $pendingCount, failed: $failedCount)';
}
