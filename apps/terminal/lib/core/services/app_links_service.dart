import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class AppLinksService {
  static final AppLinksService _instance = AppLinksService._internal();
  factory AppLinksService() => _instance;
  AppLinksService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initialize() async {
    _appLinks = AppLinks();

    // Check initial link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      // Ignore error
      if (kDebugMode) {
        print('Error handling initial link: $e');
      }
    }

    // Listen for new links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      print('Received deep link: $uri');
    }

    // Supabase handles auth callback links automatically if configured correctly,
    // but sometimes explicit handling helps, especially for custom schemes
    // or if standard handling fails.
    //
    // Specifically for specific paths like 'reset-password' or 'login',
    // we might want to navigate manually if Supabase doesn't trigger the auth state change.

    // For now, we rely on Supabase listening to the platform channel or the standard auth flows.
    // However, since we are using 'milow-admin://', we usually need to let Supabase know about this URL
    // if it contains access tokens (which it does for reset password).

    // Note: supabase_flutter >= 2.0 handles deep links internally via app_links or similar
    // if `authFlowType` is PKCE (default for mobile/desktop).
    // We just need to make sure the scheme is registered.

    // If we need custom navigation logic based on the path (e.g. show a specific dialog),
    // we can add it here.

    if (uri.scheme == 'milow-terminal') {
      if (uri.path.contains('reset-password') || uri.path.contains('login')) {
        // The session will be recovered by Supabase automatically if the URL contains parameters.
        // We can add logic here if we need to navigate to a specific page *after* auth recovery
        // if `onAuthStateChange` doesn't cover it.
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
