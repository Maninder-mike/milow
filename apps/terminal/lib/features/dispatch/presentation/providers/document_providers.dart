import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/supabase_provider.dart';

final pendingDocumentsProvider = StreamProvider<List<TripDocument>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profileAsync = ref.watch(profileProvider);

  return profileAsync.maybeWhen(
    data: (profile) {
      final companyId = profile?['company_id'] as String?;
      if (companyId == null) return Stream.value([]);

      return DocumentRepository.subscribeToPendingDocuments(
        companyId: companyId,
        supabaseClient: supabase,
      );
    },
    orElse: () => Stream.value([]),
  );
});
