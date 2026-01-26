import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/network_provider.dart';

part 'announcement_repository.g.dart';

@riverpod
AnnouncementRepository announcementRepository(Ref ref) {
  return AnnouncementRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Stream<List<Map<String, dynamic>>> announcements(Ref ref) {
  // We can't easily turn a stream into a Result logic for the stream itself without wrappers,
  // but if the stream errors, Riverpod will handle it as AsyncError.
  // We stick to returning the stream directly for now.
  return ref.watch(announcementRepositoryProvider).getAnnouncements();
}

class AnnouncementRepository {
  final CoreNetworkClient _client;

  AnnouncementRepository(this._client);

  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _client.supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<Result<void>> createAnnouncement(String body) async {
    return _client.query<void>(() async {
      await _client.supabase.from('announcements').insert({
        'title': 'Admin Announcement',
        'body': body,
        'created_at': DateTime.now().toIso8601String(),
      });
    }, operationName: 'createAnnouncement');
  }
}
