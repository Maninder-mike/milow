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

/// State object for Pagination
class LoadsPaginationState {
  final List<Load> loads;
  final bool hasMore;
  final bool isLoadingMore;

  const LoadsPaginationState({
    this.loads = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  LoadsPaginationState copyWith({
    List<Load>? loads,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return LoadsPaginationState(
      loads: loads ?? this.loads,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Paginated Loads Provider
/// Manages list state, page number, filters, and search query.
@riverpod
class PaginatedLoads extends _$PaginatedLoads {
  int _page = 0;
  static const _pageSize = 20;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Future<LoadsPaginationState> build() async {
    // Watch for realtime changes
    // Debatable: Should realtime update ONLY the current view?
    // For "deep optimization", we should listen to specific row changes, but
    // re-fetching the first page on change is safer for consistency.
    ref.watch(loadsChangeSignalProvider);

    // Reset page on rebuild (e.g. if signal fires)
    _page = 0;

    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.fetchLoads(
      page: 0,
      pageSize: _pageSize,
      statusFilter: _statusFilter,
      searchQuery: _searchQuery,
    );

    return result.fold(
      (failure) {
        AppLogger.error('Failed to fetch initial loads: ${failure.message}');
        throw failure;
      },
      (newLoads) {
        return LoadsPaginationState(
          loads: newLoads,
          hasMore: newLoads.length >= _pageSize,
          isLoadingMore: false,
        );
      },
    );
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        !currentState.hasMore ||
        currentState.isLoadingMore) {
      return;
    }

    // Set loading more flag
    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final repository = ref.read(loadRepositoryProvider);
      final nextPage = _page + 1;

      final result = await repository.fetchLoads(
        page: nextPage,
        pageSize: _pageSize,
        statusFilter: _statusFilter,
        searchQuery: _searchQuery,
      );

      result.fold(
        (failure) {
          AppLogger.error('Failed to load more: ${failure.message}');
          state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
        },
        (newLoads) {
          _page = nextPage;
          state = AsyncValue.data(
            LoadsPaginationState(
              loads: [...currentState.loads, ...newLoads],
              hasMore: newLoads.length >= _pageSize,
              isLoadingMore: false,
            ),
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSearch(String query) async {
    if (_searchQuery == query) return;
    _searchQuery = query;
    ref.invalidateSelf(); // Triggers build() with new query
  }

  Future<void> updateStatusFilter(String status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    ref.invalidateSelf();
  }
}

// Helper to keep 'delayedLoads' working (it used loadsListProvider)
// Now we use paginatedLoadsProvider but we need to watch meaningful state.
// delayedLoads likely needs 'All' or specific filter.
// Ideally, Delayed Loads should be its own query on the backend!
// But for now, we map from the visible list.
@riverpod
Future<List<Load>> delayedLoads(Ref ref) async {
  final paginationState = await ref.watch(paginatedLoadsProvider.future);
  final loads = paginationState.loads;
  final dismissedIds = ref.watch(dismissedDelayedLoadIdsProvider);

  return loads
      .where((l) => l.isDelayed && !dismissedIds.contains(l.id))
      .toList();
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
        ref.invalidate(paginatedLoadsProvider);
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
        ref.invalidate(paginatedLoadsProvider);
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
        ref.invalidate(paginatedLoadsProvider);
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

/// Alias for backwards compatibility with existing code referencing loadsListProvider.
/// Maps the paginated state to a simple `AsyncValue<List<Load>>`.
@riverpod
AsyncValue<List<Load>> loadsListLegacy(Ref ref) {
  final paginatedAsync = ref.watch(paginatedLoadsProvider);
  return paginatedAsync.whenData((state) => state.loads);
}

/// DEPRECATED: Use paginatedLoadsProvider directly for infinite scrolling.
/// This is a simple alias for backwards compatibility.
final loadsListProvider = loadsListLegacyProvider;
