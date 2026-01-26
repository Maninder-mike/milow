import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/invoice.dart';
import '../../../../core/providers/network_provider.dart';

part 'invoice_providers.g.dart';

@riverpod
InvoiceRepository invoiceRepository(Ref ref) {
  return InvoiceRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Stream<int> invoicesChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  // Use the singleton for realtime as it's separate from API requests
  final channel = Supabase.instance.client.channel('public:invoices');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'invoices',
        callback: (payload) {
          counter++;
          controller.add(counter);
        },
      )
      .subscribe();

  // Emit initial value so dependents don't stay in loading
  controller.add(counter);

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

@riverpod
Future<List<Invoice>> invoicesList(Ref ref, {String? statusFilter}) async {
  ref.watch(invoicesChangeSignalProvider);
  final repository = ref.watch(invoiceRepositoryProvider);
  final result = await repository.fetchInvoices(statusFilter: statusFilter);
  return result.fold((failure) => throw failure, (list) => list);
}

@Riverpod(keepAlive: true)
class InvoiceController extends _$InvoiceController {
  @override
  FutureOr<void> build() {}

  Future<void> createInvoice(Invoice invoice) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.createInvoice(invoice);
      return result.fold(
        (failure) => throw failure,
        (_) => ref.invalidate(invoicesListProvider),
      );
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.updateInvoice(invoice);
      return result.fold(
        (failure) => throw failure,
        (_) => ref.invalidate(invoicesListProvider),
      );
    });
  }

  Future<void> deleteInvoice(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.deleteInvoice(id);
      return result.fold(
        (failure) => throw failure,
        (_) => ref.invalidate(invoicesListProvider),
      );
    });
  }

  Future<void> updateStatus(String id, String status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.updateStatus(id, status);
      return result.fold(
        (failure) => throw failure,
        (_) => ref.invalidate(invoicesListProvider),
      );
    });
  }
}
