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

    // Join with driver_profiles to get the separated details
    final res = await _client
        .from(_profilesTable)
        .select('*, companies(*), driver_profiles(*)')
        .eq('id', uid)
        .maybeSingle();

    if (res == null) return null;

    // Flatten driver_profiles into the main map so the app doesn't break
    if (res['driver_profiles'] != null) {
      final driverData = res['driver_profiles'] as Map<String, dynamic>;
      // We rely on the fact that driver_profiles has the latest data
      // standard Map.addAll overwrites existing keys
      res.addAll(driverData);
      res.remove('driver_profiles');
    }

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

    // Also update the profile with the new URL
    if (publicUrl.isNotEmpty) {
      await updateProfile({'avatar_url': publicUrl});
    }

    return publicUrl;
  }

  static Future<void> updateProfile(Map<String, dynamic> values) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Separate fields for 'driver_profiles' vs 'profiles'
    // 'profiles' now only keeps core registry info (conceptually), but
    // we might still be syncing some fields if we haven't fully dropped them.
    // For this specific 'Enterprise Split', we primarily write to `driver_profiles`.

    final driverFields = [
      'address',
      'city',
      'state_province',
      'postal_code',
      'country',
      'date_of_birth',
      'license_number',
      'license_type',
      'citizenship',
      'fast_id',
    ];

    final sharedFields = ['full_name', 'avatar_url'];

    final driverUpdates = <String, dynamic>{};
    final baseUpdates = <String, dynamic>{};

    values.forEach((key, value) {
      if (driverFields.contains(key)) {
        driverUpdates[key] = value;
      } else if (sharedFields.contains(key)) {
        // Shared fields go to BOTH tables to maintain sync
        driverUpdates[key] = value;
        baseUpdates[key] = value;
      } else {
        // Any other field (e.g. role, specific flags) goes to base
        baseUpdates[key] = value;
      }
    });

    // 1. Update Base Profiles (Index & System Data)
    // MUST do this first because 'driver_profiles' has a foreign key to 'profiles'
    if (baseUpdates.isNotEmpty) {
      // Use upsert to create if missing (e.g. trigger failed)
      await _client.from(_profilesTable).upsert({
        ...baseUpdates,
        'id': uid,
      }, onConflict: 'id');
    }

    // 2. Update Driver Profiles (Personal Data)
    if (driverUpdates.isNotEmpty) {
      await _client.from('driver_profiles').upsert({
        ...driverUpdates,
        'id': uid,
      }, onConflict: 'id');
    }
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
