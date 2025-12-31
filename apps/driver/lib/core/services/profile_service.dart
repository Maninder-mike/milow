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

  static Future<void> updateProfile(Map<String, dynamic> values) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _client.from(_profilesTable).update(values).eq('id', uid);
  }

  /// Revoke company association - driver leaves their current company.
  /// This sets company_id and company_name to null, preventing the company
  /// from accessing the driver's data.
  static Future<void> revokeCompany() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _client
        .from(_profilesTable)
        .update({'company_id': null, 'company_name': null})
        .eq('id', uid);
  }
}
