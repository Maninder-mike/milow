import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'load_providers.dart';

final loadDocumentsProvider = FutureProvider.family<List<LoadDocument>, String>((ref, loadId) async {
  final repository = ref.watch(loadRepositoryProvider);
  final result = await repository.fetchDocumentsForLoad(loadId);
  
  return result.fold(
    (failure) {
      AppLogger.error('Failed to fetch documents for load $loadId: ${failure.message}');
      throw failure;
    },
    (docs) => docs,
  );
});

class LoadDocumentsController {
  final WidgetRef ref;
  LoadDocumentsController(this.ref);

  Future<void> updateDocumentStatus(String documentId, String loadId, DocumentStatus status, {String? notes}) async {
    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.updateDocumentStatus(documentId, status.value, rejectionReason: notes);
    
    result.fold(
      (failure) => AppLogger.error('Failed to update document status: ${failure.message}'),
      (_) => ref.invalidate(loadDocumentsProvider(loadId)),
    );
  }
}
