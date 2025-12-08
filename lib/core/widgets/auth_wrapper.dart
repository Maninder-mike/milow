import 'package:flutter/material.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/utils/app_dialogs.dart';
import 'package:milow/features/settings/presentation/pages/pin_entry_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({required this.child, super.key});

  // Static method to reset authentication state (call on sign out)
  static void resetAuthenticationState() {
    _AuthWrapperState._hasAuthenticatedThisSession = false;
    // Also clear prefetched data
    DataPrefetchService.instance.clearCache();
  }

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LocalAuthService _authService = LocalAuthService();
  static bool _hasAuthenticatedThisSession = false;
  static bool _emailVerificationSnackbarShown = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    // If already authenticated this session, skip check
    if (_hasAuthenticatedThisSession) {
      if (mounted) setState(() => _isLoading = false);
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if user is logged in to Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in, no need for PIN/biometric or data prefetch
      if (mounted) setState(() => _isLoading = false);
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // User is logged in - start prefetching data immediately in the background
    // This runs in parallel with authentication check
    final prefetchFuture = DataPrefetchService.instance.startPrefetch();

    // Check if PIN or biometric is enabled and needs authentication
    final needsAuth = await _authService.needsAuthentication();

    if (!needsAuth) {
      // No authentication needed - wait for prefetch to complete
      await prefetchFuture;
      _hasAuthenticatedThisSession = true;
      if (mounted) setState(() => _isLoading = false);
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if only biometric is enabled (no PIN)
    final isPinEnabled = await _authService.isPinEnabled();
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    final canCheckBiometrics = await _authService.canCheckBiometrics();

    if (isBiometricEnabled && canCheckBiometrics && !isPinEnabled) {
      // Only biometric enabled - authenticate directly without showing PIN page
      if (mounted) setState(() => _isLoading = false);
      await _authenticateWithBiometricOnly(prefetchFuture);
    } else {
      // PIN is enabled (with or without biometric) - show PIN entry page
      if (mounted) setState(() => _isLoading = false);
      await _showPinEntry(prefetchFuture);
    }
  }

  Future<void> _authenticateWithBiometricOnly(
    Future<void> prefetchFuture,
  ) async {
    final authenticated = await _authService.authenticateWithBiometrics();

    if (authenticated && mounted) {
      // Wait for data prefetch to complete before showing content
      await prefetchFuture;
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else if (mounted) {
      // Biometric failed - try again
      await _authenticateWithBiometricOnly(prefetchFuture);
    }
  }

  Future<void> _showPinEntry(Future<void> prefetchFuture) async {
    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PinEntryPage(),
        fullscreenDialog: true,
      ),
    );

    if (authenticated == true) {
      // Wait for data prefetch to complete before showing content
      await prefetchFuture;
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else if (mounted) {
      // If not authenticated, try again
      await _showPinEntry(prefetchFuture);
    }
  }

  void _maybeShowEmailVerifiedSnackbar() {
    if (_emailVerificationSnackbarShown) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final emailConfirmedAt = user.emailConfirmedAt; // nullable
    if (emailConfirmedAt == null) return;
    // Show only if verified recently (within last 10 minutes) to avoid noise
    try {
      final confirmedTime = DateTime.parse(emailConfirmedAt).toUtc();
      final now = DateTime.now().toUtc();
      final diff = now.difference(confirmedTime);
      if (diff.inMinutes <= 10) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppDialogs.showSuccess(
            context,
            'Your email has been successfully verified.',
          );
          _emailVerificationSnackbarShown = true;
        });
      }
    } catch (_) {
      // Ignore parse errors silently
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a simple loading indicator while checking auth
      // The splash screen handles the beautiful loading experience
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3.0)),
      );
    }
    return widget.child;
  }
}
