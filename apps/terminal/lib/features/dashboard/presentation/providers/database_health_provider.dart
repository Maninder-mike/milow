import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/providers/connectivity_provider.dart';

enum DatabaseStatus {
  connected,
  disconnected,
  checking, // Initial state
  error,
}

class DatabaseHealthState {
  final DatabaseStatus status;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  const DatabaseHealthState({
    required this.status,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  DatabaseHealthState copyWith({
    DatabaseStatus? status,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return DatabaseHealthState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final databaseHealthProvider =
    NotifierProvider<DatabaseHealthNotifier, DatabaseHealthState>(() {
      return DatabaseHealthNotifier();
    });

class DatabaseHealthNotifier extends Notifier<DatabaseHealthState> {
  Timer? _timer;

  @override
  DatabaseHealthState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });

    // Listen to connectivity to pause/resume checks
    ref.listen(connectivityProvider, (previous, next) {
      if (next is AsyncData<List<ConnectivityResult>>) {
        final results = next.value;
        if (results.contains(ConnectivityResult.none)) {
          state = state.copyWith(status: DatabaseStatus.disconnected);
          _timer?.cancel();
        } else {
          if (_timer == null || !_timer!.isActive) {
            checkConnection();
            _startPeriodicCheck();
          }
        }
      }
    });

    // Initial kick off
    checkConnection();
    _startPeriodicCheck();

    return const DatabaseHealthState(status: DatabaseStatus.checking);
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnection();
    });
  }

  Future<void> checkConnection() async {
    state = state.copyWith(isSyncing: true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .select()
          .limit(1)
          .maybeSingle();

      state = state.copyWith(
        status: DatabaseStatus.connected,
        lastSyncTime: DateTime.now(),
        isSyncing: false,
      );
    } catch (e) {
      state = state.copyWith(status: DatabaseStatus.error, isSyncing: false);
    }
  }
}
