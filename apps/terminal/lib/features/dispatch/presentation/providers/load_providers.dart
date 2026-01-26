import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

import '../../data/repositories/load_repository.dart';
import '../../domain/models/load.dart';

import '../../../../core/providers/network_provider.dart';
import '../../../../core/providers/supabase_provider.dart';

part 'load_providers.g.dart';

/// Repository Provider
@riverpod
LoadRepository loadRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  return LoadRepository(client);
}

/// Signal that emits when the 'loads' table changes
@riverpod
Stream<int> loadsChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  final supabase = ref.watch(supabaseClientProvider);
  final channel = supabase.channel('public:loads');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'loads',
        callback: (payload) {
          counter++;
          controller.add(counter);
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

/// Signal that emits when the 'stops' table changes
@riverpod
Stream<int> stopsChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  final supabase = ref.watch(supabaseClientProvider);
  final channel = supabase.channel('public:stops');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'stops',
        callback: (payload) {
          counter++;
          controller.add(counter);
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

/// List of loads (AsyncValue) by fetching from repository
@riverpod
Future<List<Load>> loadsList(Ref ref) async {
  // Watch for realtime changes to trigger re-fetch
  ref.watch(loadsChangeSignalProvider);
  ref.watch(stopsChangeSignalProvider);

  final repository = ref.watch(loadRepositoryProvider);
  final result = await repository.fetchLoads();

  // Fold the Result: throw on failure to let Riverpod handle it as AsyncError
  return result.fold((failure) {
    AppLogger.error('Failed to fetch loads: ${failure.message}');
    throw failure; // Riverpod will capture as AsyncError
  }, (loads) => loads);
}

/// Provider for dismissed delayed load IDs (session-based)
@riverpod
class DismissedDelayedLoadIds extends _$DismissedDelayedLoadIds {
  @override
  Set<String> build() => {};

  void dismiss(String loadId) {
    state = {...state, loadId};
  }
}

/// Provider for delayed loads, filtering out dismissed ones
@riverpod
Future<List<Load>> delayedLoads(Ref ref) async {
  final loads = await ref.watch(loadsListProvider.future);
  final dismissedIds = ref.watch(dismissedDelayedLoadIdsProvider);

  return loads
      .where((l) => l.isDelayed && !dismissedIds.contains(l.id))
      .toList();
}

/// Controller for Load Operations (Create, Update, Delete)
@Riverpod(keepAlive: true)
class LoadController extends _$LoadController {
  @override
  FutureOr<void> build() {
    // Initial state
  }

  Future<void> createLoad(Load load) async {
    state = const AsyncValue.loading();
    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.createLoad(load);

    state = result.fold(
      (failure) {
        AppLogger.error('Create load failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(loadsListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  Future<void> updateLoad(Load load) async {
    state = const AsyncValue.loading();
    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.updateLoad(load);

    state = result.fold(
      (failure) {
        AppLogger.error('Update load failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(loadsListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  Future<void> deleteLoad(String loadId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.deleteLoad(loadId);

    state = result.fold(
      (failure) {
        AppLogger.error('Delete load failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(loadsListProvider);
        return const AsyncValue.data(null);
      },
    );
  }
}

/// Provider to track if the user is currently in the "New Load" form
@riverpod
class IsCreatingLoad extends _$IsCreatingLoad {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

/// Provider to store the draft load data across navigation
@Riverpod(keepAlive: true)
class LoadDraft extends _$LoadDraft {
  @override
  Load build() => Load.empty();

  void update(Load Function(Load) cb) {
    state = cb(state);
  }

  void reset() => state = Load.empty();
}
