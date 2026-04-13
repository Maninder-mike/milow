import 'dart:async';

/// A simple mutex to prevent race conditions during asynchronous operations.
/// 
/// Useful for sequencing offline cache reads/writes with background refreshes
/// to prevent UI bouncing and data loss.
class AsyncMutex {
  Completer<void>? _completer;

  /// Executes [action] sequentially, waiting for any currently executing
  /// action to complete.
  Future<T> synchronized<T>(Future<T> Function() action) async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
    try {
      return await action();
    } finally {
      final c = _completer;
      _completer = null;
      c?.complete();
    }
  }
}
