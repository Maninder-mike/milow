import 'package:hive/hive.dart';

/// Represents a pending sync operation to be sent to Supabase.
///
/// Operations are stored locally when offline and processed when
/// connectivity returns. Each operation has retry logic with
/// exponential backoff.
class SyncOperation extends HiveObject {
  /// Unique identifier for this operation (UUID v4)
  String id;

  /// Target table name: 'trips' | 'fuel_entries'
  String tableName;

  /// Type of operation: 'create' | 'update' | 'delete'
  String operationType;

  /// JSON-encoded payload data
  String payload;

  /// When this operation was created
  DateTime createdAt;

  /// Number of sync attempts so far
  int retryCount;

  /// Error message from last failed attempt
  String? errorMessage;

  /// Current status: 'pending' | 'syncing' | 'failed' | 'completed'
  String status;

  /// Local ID of the record (for linking local cache to sync queue)
  String localId;

  SyncOperation({
    required this.id,
    required this.tableName,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    required this.localId,
    this.retryCount = 0,
    this.errorMessage,
    this.status = 'pending',
  });

  /// Maximum retry attempts before marking as failed
  static const int maxRetries = 5;

  /// Calculate backoff delay based on retry count
  Duration get backoffDelay {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    return Duration(seconds: 1 << retryCount);
  }

  /// Whether this operation can be retried
  bool get canRetry => retryCount < maxRetries && status != 'completed';

  /// Mark as syncing
  void markSyncing() {
    status = 'syncing';
    save();
  }

  /// Mark as completed
  void markCompleted() {
    status = 'completed';
    save();
  }

  /// Mark as failed with error
  void markFailed(String error) {
    status = 'failed';
    errorMessage = error;
    retryCount++;
    save();
  }

  /// Reset to pending for retry
  void resetToPending() {
    status = 'pending';
    save();
  }

  @override
  String toString() =>
      'SyncOperation(id: $id, table: $tableName, op: $operationType, status: $status, retries: $retryCount)';
}

/// Manual Hive TypeAdapter for SyncOperation
class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 1;

  @override
  SyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncOperation(
      id: fields[0] as String? ?? '',
      tableName: fields[1] as String? ?? '',
      operationType: fields[2] as String? ?? '',
      payload: fields[3] as String? ?? '{}',
      createdAt: fields[4] as DateTime? ?? DateTime.now(),
      localId: fields[8] as String? ?? '',
      retryCount: fields[5] as int? ?? 0,
      errorMessage: fields[6] as String?,
      status: fields[7] as String? ?? 'pending',
    );
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tableName)
      ..writeByte(2)
      ..write(obj.operationType)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.errorMessage)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.localId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
