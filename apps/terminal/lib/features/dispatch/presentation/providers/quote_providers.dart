import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/quote_repository.dart';
import '../../domain/models/quote.dart';

part 'quote_providers.g.dart';

/// Repository Provider
@riverpod
QuoteRepository quoteRepository(Ref ref) {
  return QuoteRepository(Supabase.instance.client);
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
  return repository.fetchQuotes();
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
    state = await AsyncValue.guard(() async {
      final repository = ref.read(quoteRepositoryProvider);
      await repository.createQuote(quote);
      ref.invalidate(quotesListProvider);
    });
  }

  Future<void> updateQuote(Quote quote) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(quoteRepositoryProvider);
      await repository.updateQuote(quote);
      ref.invalidate(quotesListProvider);
    });
  }

  Future<void> deleteQuote(String quoteId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(quoteRepositoryProvider);
      await repository.deleteQuote(quoteId);
      ref.invalidate(quotesListProvider);
    });
  }
}
