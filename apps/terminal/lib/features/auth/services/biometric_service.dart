import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyPin = 'user_pin';

  Future<bool> get isBiometricAvailable async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to login',
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _keyPin);
    return storedPin == pin;
  }

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _keyPin);
    return pin != null;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _keyPin);
  }

  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<Map<String, String>?> getCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }

  Future<bool> hasStoredCredentials() async {
    final creds = await getCredentials();
    return creds != null;
  }
}
