import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/logging_service.dart';

/// Enterprise-grade auth resilience service.
///
/// Implements proactive token refresh strategy to prevent
/// `AuthRetryableFetchException` crashes from expired tokens.
///
/// Key features:
/// - Proactive refresh: Refreshes tokens 5 minutes before expiry
/// - Connectivity-aware: Waits for network before attempting refresh
/// - Graceful degradation: Errors are logged, not thrown
class AuthResilienceService {
  static AuthResilienceService? _instance;
  static AuthResilienceService get instance =>
      _instance ??= AuthResilienceService._();

  AuthResilienceService._();

  Timer? _refreshTimer;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isRefreshing = false;
  bool _pendingRefreshOnReconnect = false;

  /// Buffer time before token expiry to trigger refresh.
  static const _refreshBuffer = Duration(minutes: 5);

  /// Minimum delay between refresh attempts.
  static const _minRefreshInterval = Duration(seconds: 30);

  DateTime? _lastRefreshAttempt;

  /// Initialize the service. Call after Supabase.initialize().
  void init() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
      onError: _onAuthError,
    );

    // Listen for connectivity changes to retry pending refreshes
    _connectivitySubscription = connectivityService.onConnectivityChanged
        .listen((isOnline) {
          if (isOnline && _pendingRefreshOnReconnect) {
            debugPrint('🔄 Connectivity restored - retrying token refresh');
            _pendingRefreshOnReconnect = false;
            _refreshToken();
          }
        });

    // Schedule refresh for existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _scheduleRefresh(session);
    }

    debugPrint('[AuthResilienceService] Initialized');
  }

  void _onAuthStateChange(AuthState data) {
    final session = data.session;

    if (session != null) {
      _scheduleRefresh(session);
    } else {
      _cancelRefresh();
    }
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    final errorStr = error.toString().toLowerCase();

    // Network errors are transient - don't crash
    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('clientexception') ||
        errorStr.contains('authretryablefetchexception')) {
      debugPrint('⚠️ Auth listener network error (non-fatal): $error');

      // Mark for retry when connectivity returns
      _pendingRefreshOnReconnect = true;
      return;
    }

    // Log unexpected errors
    logger.error(
      'AuthResilienceService',
      'Auth state error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _scheduleRefresh(Session session) {
    _cancelRefresh();

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      debugPrint('⚠️ Session has no expiry time');
      return;
    }

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final refreshTime = expiryTime.subtract(_refreshBuffer);
    final now = DateTime.now();
    final delay = refreshTime.difference(now);

    if (delay.isNegative) {
      // Token already expired or about to expire - refresh immediately
      debugPrint('⚡ Token expiring soon, refreshing immediately');
      _refreshToken();
    } else {
      debugPrint('📅 Token refresh scheduled in ${delay.inMinutes} minutes');
      _refreshTimer = Timer(delay, _refreshToken);
    }
  }

  void _cancelRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshToken() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      debugPrint('⏳ Refresh already in progress, skipping');
      return;
    }

    // Rate limit refresh attempts
    final now = DateTime.now();
    if (_lastRefreshAttempt != null &&
        now.difference(_lastRefreshAttempt!) < _minRefreshInterval) {
      debugPrint('⏳ Too soon since last refresh attempt, skipping');
      return;
    }

    // Check connectivity before attempting refresh
    if (!connectivityService.isOnline) {
      debugPrint('📵 Offline - deferring token refresh');
      _pendingRefreshOnReconnect = true;
      return;
    }

    _isRefreshing = true;
    _lastRefreshAttempt = now;

    try {
      debugPrint('🔄 Refreshing auth token...');
      await Supabase.instance.client.auth.refreshSession();
      debugPrint('✅ Token refreshed successfully');
      _pendingRefreshOnReconnect = false;
    } catch (e, stack) {
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('clientexception')) {
        // Network error - retry when connectivity returns
        debugPrint('📵 Network error during refresh - will retry on reconnect');
        _pendingRefreshOnReconnect = true;
      } else if (e is AuthException && e.code == 'refresh_token_already_used') {
        // Token was already used (concurrent refresh from another device)
        debugPrint('⚠️ Refresh token already used - signing out');
        await Supabase.instance.client.auth.signOut();
      } else {
        // Log other errors but don't crash
        debugPrint('❌ Token refresh failed: $e');
        unawaited(
          logger.error(
            'AuthResilienceService',
            'Token refresh failed',
            error: e,
            stackTrace: stack,
          ),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Force a token refresh (useful for testing or manual retry).
  Future<void> forceRefresh() => _refreshToken();

  /// Dispose the service.
  void dispose() {
    _cancelRefresh();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _authSubscription = null;
    _connectivitySubscription = null;
  }
}

/// Global instance for easy access.
AuthResilienceService get authResilienceService =>
    AuthResilienceService.instance;
