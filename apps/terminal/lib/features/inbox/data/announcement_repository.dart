import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'announcement_repository.g.dart';

@riverpod
AnnouncementRepository announcementRepository(Ref ref) {
  return AnnouncementRepository(Supabase.instance.client);
}

@riverpod
Stream<List<Map<String, dynamic>>> announcements(Ref ref) {
  return ref.watch(announcementRepositoryProvider).getAnnouncements();
}

class AnnouncementRepository {
  final SupabaseClient _client;

  AnnouncementRepository(this._client);

  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> createAnnouncement(String body) async {
    await _client.from('announcements').insert({
      'title': 'Admin Announcement',
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
