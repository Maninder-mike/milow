import 'package:flutter/material.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/features/settings/presentation/pages/pin_entry_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  // Static method to reset authentication state (call on sign out)
  static void resetAuthenticationState() {
    _AuthWrapperState._hasAuthenticatedThisSession = false;
  }

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LocalAuthService _authService = LocalAuthService();
  bool _isChecking = true;
  bool _isAuthenticated = false;
  static bool _hasAuthenticatedThisSession = false;
  static bool _emailVerificationSnackbarShown = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // If already authenticated this session, skip check
    if (_hasAuthenticatedThisSession) {
      setState(() {
        _isAuthenticated = true;
        _isChecking = false;
      });
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if user is logged in to Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in, no need for PIN/biometric
      setState(() {
        _isAuthenticated = true;
        _isChecking = false;
      });
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if PIN or biometric is enabled and needs authentication
    final needsAuth = await _authService.needsAuthentication();

    if (!needsAuth) {
      // No authentication needed
      setState(() {
        _isAuthenticated = true;
        _isChecking = false;
      });
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if only biometric is enabled (no PIN)
    final isPinEnabled = await _authService.isPinEnabled();
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    final canCheckBiometrics = await _authService.canCheckBiometrics();

    if (isBiometricEnabled && canCheckBiometrics && !isPinEnabled) {
      // Only biometric enabled - authenticate directly without showing PIN page
      setState(() {
        _isChecking = false;
      });
      await _authenticateWithBiometricOnly();
    } else {
      // PIN is enabled (with or without biometric) - show PIN entry page
      setState(() {
        _isChecking = false;
      });
      _showPinEntry();
    }
  }

  Future<void> _authenticateWithBiometricOnly() async {
    final authenticated = await _authService.authenticateWithBiometrics();

    if (authenticated && mounted) {
      setState(() {
        _isAuthenticated = true;
      });
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else if (mounted) {
      // Biometric failed - try again
      _authenticateWithBiometricOnly();
    }
  }

  Future<void> _showPinEntry() async {
    final authenticated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PinEntryPage(),
        fullscreenDialog: true,
      ),
    );

    setState(() {
      _isAuthenticated = authenticated ?? false;
    });

    if (_isAuthenticated) {
      // Mark as authenticated for this session
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else {
      // If not authenticated, try again
      _showPinEntry();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your email has been successfully verified.'),
            ),
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
    if (_isChecking) {
      // Show loading screen while checking
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF007AFF)),
        ),
      );
    }

    if (!_isAuthenticated) {
      // Show empty screen while waiting for authentication
      return const Scaffold(body: SizedBox.shrink());
    }

    // Show the actual app content
    return widget.child;
  }
}
