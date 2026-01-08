import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_device_integrity/app_device_integrity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service for verifying app and device integrity using Google Play Integrity API.
///
/// This service:
/// 1. Requests an integrity token from Play Integrity API
/// 2. Sends the token to a Supabase Edge Function for verification
/// 3. Returns the verification result
///
/// **Important**: Verification happens server-side for security.
class IntegrityService {
  // Google Cloud Project Number for Milow
  static const int _cloudProjectNumber = 799615226888;

  /// Plugin instance
  static final AppDeviceIntegrity _plugin = AppDeviceIntegrity();

  /// Cached verification result to avoid repeated checks
  static bool? _lastVerificationResult;
  static DateTime? _lastVerificationTime;

  /// Cache duration - re-verify after this time
  static const Duration _cacheDuration = Duration(hours: 24);

  /// Verify app and device integrity.
  ///
  /// Returns `true` if verification passed or was skipped (debug mode).
  /// Returns `false` if verification failed.
  ///
  /// Set [forceRefresh] to `true` to bypass cache.
  static Future<IntegrityResult> verify({bool forceRefresh = false}) async {
    // Skip in debug mode - Play Integrity doesn't work in debug
    if (kDebugMode) {
      debugPrint('IntegrityService: Skipping verification in debug mode');
      return const IntegrityResult(
        isValid: true,
        message: 'Debug mode - verification skipped',
        skipped: true,
      );
    }

    // Only run on Android
    if (!Platform.isAndroid) {
      return const IntegrityResult(
        isValid: true,
        message: 'Non-Android platform - verification skipped',
        skipped: true,
      );
    }

    // Check cache
    if (!forceRefresh && _isCacheValid()) {
      return IntegrityResult(
        isValid: _lastVerificationResult!,
        message: 'Cached result',
        skipped: false,
      );
    }

    try {
      // Step 1: Request integrity token from Play Integrity API
      final token = await _requestIntegrityToken();
      if (token == null || token.isEmpty) {
        return const IntegrityResult(
          isValid: false,
          message: 'Failed to obtain integrity token',
          skipped: false,
        );
      }

      // Step 2: Send token to backend for verification
      final result = await _verifyTokenWithBackend(token);

      // Cache the result
      _lastVerificationResult = result.isValid;
      _lastVerificationTime = DateTime.now();

      return result;
    } catch (e) {
      debugPrint('IntegrityService: Verification error: $e');
      return IntegrityResult(
        isValid: false,
        message: 'Verification error: $e',
        skipped: false,
      );
    }
  }

  /// Request an integrity token from Play Integrity API
  static Future<String?> _requestIntegrityToken() async {
    try {
      // Generate a session UUID (nonce) for this request
      final sessionId = const Uuid().v4();

      final token = await _plugin.getAttestationServiceSupport(
        challengeString: sessionId,
        gcp: _cloudProjectNumber,
      );

      return token;
    } catch (e) {
      debugPrint('IntegrityService: Failed to request token: $e');
      return null;
    }
  }

  /// Send the integrity token to Supabase Edge Function for verification
  static Future<IntegrityResult> _verifyTokenWithBackend(String token) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'verify-integrity',
        body: {'integrityToken': token},
      );

      if (response.status != 200) {
        return IntegrityResult(
          isValid: false,
          message: 'Backend verification failed: ${response.status}',
          skipped: false,
        );
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return const IntegrityResult(
          isValid: false,
          message: 'Invalid backend response',
          skipped: false,
        );
      }

      final isValid = data['valid'] as bool? ?? false;
      final message = data['message'] as String? ?? 'Unknown';
      final verdict = data['verdict'] as Map<String, dynamic>?;

      return IntegrityResult(
        isValid: isValid,
        message: message,
        skipped: false,
        deviceVerdict: verdict?['deviceIntegrity'] as String?,
        appVerdict: verdict?['appIntegrity'] as String?,
      );
    } catch (e) {
      debugPrint('IntegrityService: Backend verification error: $e');
      return IntegrityResult(
        isValid: false,
        message: 'Backend error: $e',
        skipped: false,
      );
    }
  }

  /// Check if cached result is still valid
  static bool _isCacheValid() {
    if (_lastVerificationResult == null || _lastVerificationTime == null) {
      return false;
    }
    return DateTime.now().difference(_lastVerificationTime!) < _cacheDuration;
  }

  /// Clear cached verification result
  static void clearCache() {
    _lastVerificationResult = null;
    _lastVerificationTime = null;
  }
}

/// Result of an integrity verification check
class IntegrityResult {
  final bool isValid;
  final String message;
  final bool skipped;
  final String? deviceVerdict;
  final String? appVerdict;

  const IntegrityResult({
    required this.isValid,
    required this.message,
    required this.skipped,
    this.deviceVerdict,
    this.appVerdict,
  });

  @override
  String toString() {
    return 'IntegrityResult(isValid: $isValid, message: $message, skipped: $skipped)';
  }
}
