import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:terminal/core/providers/network_provider.dart';
import 'package:terminal/features/settings/providers/company_provider.dart';

part 'announcement_repository.g.dart';

@riverpod
AnnouncementRepository announcementRepository(Ref ref) {
  return AnnouncementRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Stream<List<Map<String, dynamic>>> announcements(Ref ref) {
  final companyIdAsync = ref.watch(currentCompanyIdProvider);
  return companyIdAsync.when(
    data: (id) =>
        ref.watch(announcementRepositoryProvider).getAnnouncements(id),
    loading: () => const Stream.empty(),
    error: (err, st) => Stream.error(err, st),
  );
}

class AnnouncementRepository {
  final CoreNetworkClient _client;

  AnnouncementRepository(this._client);

  Stream<List<Map<String, dynamic>>> getAnnouncements(String companyId) {
    return _client.supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
  }

  Future<Result<void>> createAnnouncement(
    String title,
    String body,
    String companyId,
  ) async {
    return _client.query<void>(() async {
      await _client.supabase.from('announcements').insert({
        'title': title,
        'body': body,
        'company_id': companyId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }, operationName: 'createAnnouncement');
  }

  Future<Result<void>> deleteAnnouncement(String id) async {
    return _client.query<void>(() async {
      await _client.supabase.from('announcements').delete().eq('id', id);
    }, operationName: 'deleteAnnouncement');
  }
}
