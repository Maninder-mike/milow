import 'dart:async';
import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/quote_repository.dart';
import '../../domain/models/quote.dart';
import '../../../../core/providers/network_provider.dart';

part 'quote_providers.g.dart';

/// Repository Provider
@riverpod
QuoteRepository quoteRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  return QuoteRepository(client);
}

/// Signal that emits when the 'quotes' table changes
@riverpod
Stream<int> quotesChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  final channel = Supabase.instance.client.channel('public:quotes');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'quotes',
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

/// List of quotes (AsyncValue) by fetching from repository
@riverpod
Future<List<Quote>> quotesList(Ref ref) async {
  // Watch for realtime changes to trigger re-fetch
  ref.watch(quotesChangeSignalProvider);

  final repository = ref.watch(quoteRepositoryProvider);
  final result = await repository.fetchQuotes();

  return result.fold((failure) {
    AppLogger.error('Failed to fetch quotes: ${failure.message}');
    throw failure;
  }, (quotes) => quotes);
}

/// Controller for Quote Operations (Create, Update, Delete)
@Riverpod(keepAlive: true)
class QuoteController extends _$QuoteController {
  @override
  FutureOr<void> build() {
    // Initial state
  }

  Future<void> createQuote(Quote quote) async {
    state = const AsyncValue.loading();
    final repository = ref.read(quoteRepositoryProvider);
    final result = await repository.createQuote(quote);

    state = result.fold(
      (failure) {
        AppLogger.error('Create quote failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(quotesListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  Future<void> updateQuote(Quote quote) async {
    state = const AsyncValue.loading();
    final repository = ref.read(quoteRepositoryProvider);
    final result = await repository.updateQuote(quote);

    state = result.fold(
      (failure) {
        AppLogger.error('Update quote failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(quotesListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  Future<void> deleteQuote(String quoteId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(quoteRepositoryProvider);
    final result = await repository.deleteQuote(quoteId);

    state = result.fold(
      (failure) {
        AppLogger.error('Delete quote failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(quotesListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  /// Update just the status of a quote
  Future<void> updateQuoteStatus(String quoteId, String status) async {
    state = const AsyncValue.loading();
    final repository = ref.read(quoteRepositoryProvider);
    final result = await repository.updateStatus(quoteId, status);

    state = result.fold(
      (failure) {
        AppLogger.error('Update quote status failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(quotesListProvider);
        return const AsyncValue.data(null);
      },
    );
  }

  /// Clone an existing quote (creates a new draft copy)
  Future<void> cloneQuote(Quote original) async {
    state = const AsyncValue.loading();
    final repository = ref.read(quoteRepositoryProvider);
    final clonedQuote = Quote(
      id: '',
      loadId: original.loadId,
      loadReference: original.loadReference,
      status: 'draft',
      lineItems: original.lineItems,
      total: original.total,
      notes: original.notes,
      expiresOn: DateTime.now().add(const Duration(days: 7)),
    );
    final result = await repository.createQuote(clonedQuote);

    state = result.fold(
      (failure) {
        AppLogger.error('Clone quote failed: ${failure.message}');
        return AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        ref.invalidate(quotesListProvider);
        return const AsyncValue.data(null);
      },
    );
  }
}
