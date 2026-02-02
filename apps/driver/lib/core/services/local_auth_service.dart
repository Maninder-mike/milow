import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocalAuthService {
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _pinHashKey = 'pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastAuthTimeKey = 'last_auth_time';
  static const String _userEmailKey = 'user_email';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      if (kDebugMode) {
        debugPrint('Available biometrics: $biometrics');
      }
      return biometrics;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting available biometrics: $e');
      }
      return [];
    }
  }

  // Check if device supports Face ID/Face Recognition
  Future<bool> hasFaceRecognition() async {
    final biometrics = await getAvailableBiometrics();
    // Check for face recognition (iOS Face ID or Android Face Unlock)
    final hasFace = biometrics.contains(BiometricType.face);
    // On some Android devices, face unlock might be reported as 'weak' or 'strong'
    final hasStrong = biometrics.contains(BiometricType.strong);
    final hasWeak = biometrics.contains(BiometricType.weak);

    if (kDebugMode) {
      debugPrint('Face: $hasFace, Strong: $hasStrong, Weak: $hasWeak');
    }

    // If device has face biometric, return true
    // Otherwise, if it has strong/weak but no fingerprint, it might be face
    if (hasFace) return true;

    // Check if strong/weak biometric is available and no fingerprint
    // This could indicate face unlock on Android
    final hasFingerprint = biometrics.contains(BiometricType.fingerprint);
    if ((hasStrong || hasWeak) && !hasFingerprint) {
      return true; // Likely face unlock
    }

    return false;
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      // Get available biometrics to determine the right message
      final biometrics = await getAvailableBiometrics();
      final hasFace = biometrics.contains(BiometricType.face);
      final hasFingerprint = biometrics.contains(BiometricType.fingerprint);

      // Determine the appropriate message
      String localizedReason;
      if (hasFace && !hasFingerprint) {
        localizedReason = 'Please authenticate with Face ID to access the app';
      } else if (hasFingerprint && !hasFace) {
        localizedReason =
            'Please authenticate with fingerprint to access the app';
      } else if (hasFace && hasFingerprint) {
        // Device has both - let system decide, use generic message
        localizedReason = 'Please authenticate to access the app';
      } else {
        // Strong/weak biometric (could be face or other)
        localizedReason = 'Please authenticate to access the app';
      }

      if (kDebugMode) {
        debugPrint('Available biometrics: $biometrics');
        debugPrint('Has Face: $hasFace, Has Fingerprint: $hasFingerprint');
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (isAuthenticated) {
        await _updateLastAuthTime();
      }

      return isAuthenticated;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Biometric authentication error: $e');
      }
      return false;
    }
  }

  // PIN Management
  Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _pinEnabledKey);
    return val == 'true';
  }

  Future<void> setPinEnabled(bool enabled) async {
    await _storage.write(key: _pinEnabledKey, value: enabled.toString());
  }

  Future<bool> hasPin() async {
    return await _storage.containsKey(key: _pinHashKey);
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> setPin(String pin) async {
    final hashedPin = _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hashedPin);
    await setPinEnabled(true);
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);

    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    final isValid = inputHash == storedHash;

    if (isValid) {
      await _updateLastAuthTime();
    }

    return isValid;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await setPinEnabled(false);
  }

  // Biometric preference management
  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  // Check if user needs to authenticate (based on session)
  Future<bool> needsAuthentication() async {
    final isPinEnabled = await this.isPinEnabled();
    final isBiometricEnabled = await this.isBiometricEnabled();

    // If neither is enabled, no auth needed
    if (!isPinEnabled && !isBiometricEnabled) {
      return false;
    }

    // Check if user has authenticated recently (within 5 minutes)
    final lastAuthTimeStr = await _storage.read(key: _lastAuthTimeKey);
    if (lastAuthTimeStr != null) {
      final lastAuthTime = int.tryParse(lastAuthTimeStr);
      if (lastAuthTime != null) {
        final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
        final now = DateTime.now();
        final difference = now.difference(lastAuth);

        // If authenticated within last 5 minutes, no need to re-authenticate
        if (difference.inMinutes < 5) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _updateLastAuthTime() async {
    await _storage.write(
      key: _lastAuthTimeKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Store user email for auto-login
  Future<void> storeUserEmail(String email) async {
    await _storage.write(key: _userEmailKey, value: email);
  }

  Future<String?> getStoredUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  // Clear all auth data
  Future<void> clearAuthData() async {
    await _storage.deleteAll();
  }
}
