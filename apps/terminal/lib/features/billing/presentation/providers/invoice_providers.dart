import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/invoice.dart';

part 'invoice_providers.g.dart';

@riverpod
InvoiceRepository invoiceRepository(Ref ref) {
  return InvoiceRepository(Supabase.instance.client);
}

@riverpod
Stream<int> invoicesChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

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
  return repository.fetchInvoices(statusFilter: statusFilter);
}

@Riverpod(keepAlive: true)
class InvoiceController extends _$InvoiceController {
  @override
  FutureOr<void> build() {}

  Future<void> createInvoice(Invoice invoice) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      await repository.createInvoice(invoice);
      ref.invalidate(invoicesListProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      await repository.updateInvoice(invoice);
      ref.invalidate(invoicesListProvider);
    });
  }

  Future<void> deleteInvoice(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      await repository.deleteInvoice(id);
      ref.invalidate(invoicesListProvider);
    });
  }

  Future<void> updateStatus(String id, String status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(invoiceRepositoryProvider);
      await repository.updateStatus(id, status);
      ref.invalidate(invoicesListProvider);
    });
  }
}
