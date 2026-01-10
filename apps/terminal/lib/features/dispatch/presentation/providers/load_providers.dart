import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/load_repository.dart';
import '../../domain/models/load.dart';

part 'load_providers.g.dart';

/// Repository Provider
@riverpod
LoadRepository loadRepository(Ref ref) {
  return LoadRepository(Supabase.instance.client);
}

/// Signal that emits when the 'loads' table changes
@riverpod
Stream<int> loadsChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  final channel = Supabase.instance.client.channel('public:loads');

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

/// List of loads (AsyncValue) by fetching from repository
@riverpod
Future<List<Load>> loadsList(Ref ref) async {
  // Watch for realtime changes to trigger re-fetch
  ref.watch(loadsChangeSignalProvider);

  final repository = ref.watch(loadRepositoryProvider);
  return repository.fetchLoads();
}

/// Controller for Load Operations (Create, Update, Delete)
@Riverpod(keepAlive: true)
class LoadController extends _$LoadController {
  @override
  FutureOr<void> build() {
    // Check initial state or nothing
  }

  Future<void> createLoad(Load load) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(loadRepositoryProvider);
      await repository.createLoad(load);
      // Refresh the list
      ref.invalidate(loadsListProvider);
    });
  }

  Future<void> updateLoad(Load load) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(loadRepositoryProvider);
      await repository.updateLoad(load);
      ref.invalidate(loadsListProvider);
    });
  }

  Future<void> deleteLoad(String loadId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(loadRepositoryProvider);
      await repository.deleteLoad(loadId);
      ref.invalidate(loadsListProvider);
    });
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
