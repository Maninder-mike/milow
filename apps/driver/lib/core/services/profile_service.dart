import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static const String _profilesTable = 'profiles';
  static const String _avatarsBucket = 'avatars';

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final res = await _client
        .from(_profilesTable)
        .select('*, companies(*)')
        .eq('id', uid)
        .maybeSingle();
    return res;
  }

  static Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final path = '$uid/$filename';
    await _client.storage
        .from(_avatarsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl = _client.storage.from(_avatarsBucket).getPublicUrl(path);
    return publicUrl;
  }

  static Future<void> upsertProfile(Map<String, dynamic> values) async {
    final uid = currentUserId;
    if (uid == null) return;
    final payload = {'id': uid, ...values};
    await _client.from(_profilesTable).upsert(payload).eq('id', uid);
  }
}
