import 'package:flutter/material.dart';
import 'package:milow/core/services/local_auth_service.dart';
import 'package:milow/features/settings/presentation/pages/pin_entry_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LocalAuthService _authService = LocalAuthService();
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Check if user is logged in to Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in, no need for PIN/biometric
      setState(() {
        _isAuthenticated = true;
        _isChecking = false;
      });
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
      return;
    }

    setState(() {
      _isChecking = false;
    });

    // Show PIN entry screen
    _showPinEntry();
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

    if (!_isAuthenticated) {
      // If not authenticated, try again
      _showPinEntry();
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
