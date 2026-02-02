import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [LocalStorage] implementation that uses [FlutterSecureStorage] to persist
/// the user session securely.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  final FlutterSecureStorage _storage;
  static const String _key = 'supabase_persist_session';

  @override
  Future<void> initialize() async {
    // No initialization needed for FlutterSecureStorage
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    return _storage.write(key: _key, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    return _storage.delete(key: _key);
  }
}
