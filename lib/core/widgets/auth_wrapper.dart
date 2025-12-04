import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/features/settings/presentation/pages/pin_entry_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

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
  bool _isChecking = true;
  bool _isAuthenticated = false;
  bool _isDataReady = false;
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
        _isDataReady = true;
        _isChecking = false;
      });
      _maybeShowEmailVerifiedSnackbar();
      return;
    }

    // Check if user is logged in to Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in, no need for PIN/biometric or data prefetch
      setState(() {
        _isAuthenticated = true;
        _isDataReady = true;
        _isChecking = false;
      });
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
      setState(() {
        _isAuthenticated = true;
        _isDataReady = true;
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
      await _authenticateWithBiometricOnly(prefetchFuture);
    } else {
      // PIN is enabled (with or without biometric) - show PIN entry page
      setState(() {
        _isChecking = false;
      });
      _showPinEntry(prefetchFuture);
    }
  }

  Future<void> _authenticateWithBiometricOnly(
    Future<void> prefetchFuture,
  ) async {
    final authenticated = await _authService.authenticateWithBiometrics();

    if (authenticated && mounted) {
      // Wait for data prefetch to complete before showing content
      await prefetchFuture;
      setState(() {
        _isAuthenticated = true;
        _isDataReady = true;
      });
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else if (mounted) {
      // Biometric failed - try again
      _authenticateWithBiometricOnly(prefetchFuture);
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
      setState(() {
        _isAuthenticated = true;
        _isDataReady = true;
      });
      _hasAuthenticatedThisSession = true;
      _maybeShowEmailVerifiedSnackbar();
    } else if (mounted) {
      // If not authenticated, try again
      _showPinEntry(prefetchFuture);
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
      // Show beautiful loading screen while checking
      return _buildLoadingScreen(context);
    }

    if (!_isAuthenticated || !_isDataReady) {
      // Show loading screen while waiting for authentication or data
      return _buildLoadingScreen(context);
    }

    // Show the actual app content
    return widget.child;
  }

  Widget _buildLoadingScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon with animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // App Name
            Text(
              'Milow',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trucking Made Simple',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator with shimmer effect
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  // Progress bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 2000),
                    builder: (context, value, child) {
                      return Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your data...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
