import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Check if device supports Face ID/Face Recognition
  Future<bool> hasFaceRecognition() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
      );

      if (isAuthenticated) {
        await _updateLastAuthTime();
      }

      return isAuthenticated;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Biometric authentication error: $e');
      }
      return false;
    }
  }

  // PIN Management
  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? false;
  }

  Future<void> setPinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, enabled);
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinHashKey) != null;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPin = _hashPin(pin);
    await prefs.setString(_pinHashKey, hashedPin);
    await prefs.setBool(_pinEnabledKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);

    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    final isValid = inputHash == storedHash;

    if (isValid) {
      await _updateLastAuthTime();
    }

    return isValid;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.setBool(_pinEnabledKey, false);
  }

  // Biometric preference management
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // Check if user needs to authenticate (based on session)
  Future<bool> needsAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    final isPinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
    final isBiometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;

    // If neither is enabled, no auth needed
    if (!isPinEnabled && !isBiometricEnabled) {
      return false;
    }

    // Check if user has authenticated recently (within 5 minutes)
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    if (lastAuthTime != null) {
      final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
      final now = DateTime.now();
      final difference = now.difference(lastAuth);

      // If authenticated within last 5 minutes, no need to re-authenticate
      if (difference.inMinutes < 5) {
        return false;
      }
    }

    return true;
  }

  Future<void> _updateLastAuthTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAuthTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Store user email for auto-login
  Future<void> storeUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Clear all auth data
  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinEnabledKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_lastAuthTimeKey);
    await prefs.remove(_userEmailKey);
  }
}
