import 'package:flutter/foundation.dart';

enum SyncStatus {
  idle,
  syncing,
  error,
  upToDate,
}

class SyncStatusProvider extends ChangeNotifier {
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool get isSyncing => _status == SyncStatus.syncing;

  void setStatus(SyncStatus status, {String? error}) {
    if (_status == status && _lastError == error) return;
    
    _status = status;
    _lastError = error;
    if (status == SyncStatus.upToDate) {
      _lastSyncTime = DateTime.now();
    }
    notifyListeners();
  }

  void startSync() => setStatus(SyncStatus.syncing);
  void completeSync() => setStatus(SyncStatus.upToDate);
  void setError(String error) => setStatus(SyncStatus.error, error: error);
}

final syncStatusProvider = SyncStatusProvider();
