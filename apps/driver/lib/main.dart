import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:animations/animations.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow/core/theme/app_theme.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/theme_service.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/locale_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:milow/core/services/trip_parser_service.dart';
import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/local_trip_store.dart';
import 'package:milow/core/services/local_fuel_store.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/local_expense_store.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/geofence_service.dart';
import 'package:milow/core/services/analytics_service.dart';
import 'package:milow/core/services/driver_remote_config_service.dart';
import 'package:milow/core/services/performance_service.dart';
import 'package:milow/core/services/auth_resilience_service.dart';
import 'package:milow/core/services/secure_local_storage.dart';
import 'package:milow/core/models/sync_operation.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:milow/core/services/version_check_service.dart';
import 'package:milow/core/presentation/pages/force_update_page.dart';

// Placeholder imports - will be replaced with actual pages

import 'package:milow/features/auth/presentation/pages/login_page.dart';
import 'package:milow/features/auth/presentation/pages/sign_up_page.dart';
import 'package:milow/features/settings/presentation/pages/feedback_page.dart';
import 'package:milow/features/settings/presentation/pages/privacy_security_page.dart';
import 'package:milow/features/settings/presentation/pages/appearance_page.dart';
import 'package:milow/features/settings/presentation/pages/edit_profile_page.dart';
import 'package:milow/features/settings/presentation/pages/notifications_page.dart';

import 'package:milow/features/settings/presentation/pages/language_page.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/features/trips/presentation/pages/scan_document_page.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/expenses/presentation/pages/expenses_list_page.dart';
import 'package:milow/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:milow/features/settings/presentation/pages/units_settings_page.dart';
import 'package:milow/features/dashboard/presentation/pages/driver_tools_page.dart';
// Note: tab pages are hosted via TabsShell
import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/core/widgets/tabs_shell.dart';
import 'package:milow/core/widgets/splash_screen.dart';
import 'package:milow/features/auth/presentation/pages/email_verified_page.dart';
import 'package:milow/features/auth/presentation/pages/reset_password_page.dart';
import 'package:milow/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep native splash screen up until we're ready
  widgetsBinding.deferFirstFrame();

  // 2. Critical Base Services (Blocking)
  try {
    // 1. Initialize Firebase FIRST (PerformanceService depends on it)
    debugPrint('🚀 [Init] Initializing Firebase...');
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ [Init] Firebase initialization timed out after 10s');
        throw TimeoutException('Firebase initialization timed out');
      },
    );
    debugPrint('✅ [Init] Firebase initialized');

    // Start Cold Start Trace (after Firebase is ready)
    await PerformanceService.instance.startColdStartTrace();
    PerformanceService.instance.logStartupMilestone('app_launched');

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      // Handle "refresh_token_already_used" error to prevent crash loop
      if (error is AuthException &&
          error.code == 'refresh_token_already_used') {
        debugPrint('⚠️ Refresh token already used. Signing out...');
        Supabase.instance.client.auth.signOut();
        return true;
      }

      // Classify transient network errors as NON-FATAL
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('authretryablefetchexception') ||
          errorStr.contains('connection refused') ||
          errorStr.contains('network is unreachable')) {
        debugPrint('📵 Transient network error (non-fatal): $error');
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
        return true;
      }

      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // 3. Load environment and UI settings (Blocking)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    debugPrint('🚀 [Init] Loading environment and base services...');
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      dotenv
          .load(fileName: '.env')
          .then((_) => debugPrint('✅ [Init] .env loaded')),
      logger.init().then((_) => debugPrint('✅ [Init] Logger initialized')),
      localeService.loadLocale().then(
        (_) => debugPrint('✅ [Init] Locale loaded'),
      ),
      connectivityService.init().then(
        (_) => debugPrint('✅ [Init] Connectivity initialized'),
      ),
    ]).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint(
          '⚠️ [Init] Base services initialization timed out after 15s',
        );
        return []; // Return empty list to satisfy type
      },
    );

    PerformanceService.instance.logStartupMilestone('environment_loaded');

    // 4. Critical Dependencies (Supabase & Hive)
    debugPrint('🚀 [Init] Initializing Supabase and Hive...');
    await Future.wait([
      Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: SecureLocalStorage(),
        ),
      ).then((_) => debugPrint('✅ [Init] Supabase initialized')),
      Hive.initFlutter().then((_) async {
        debugPrint('🚀 [Init] Initializing Hive adapters and stores...');
        Hive.registerAdapter(SyncOperationAdapter());
        // Stores needed for dashboard/cached data
        await Future.wait([
          LocalProfileStore.init().then(
            (_) => debugPrint('✅ [Init] LocalProfileStore ready'),
          ),
          LocalTripStore.init().then(
            (_) => debugPrint('✅ [Init] LocalTripStore ready'),
          ),
          LocalFuelStore.init().then(
            (_) => debugPrint('✅ [Init] LocalFuelStore ready'),
          ),
          LocalDocumentStore.init().then(
            (_) => debugPrint('✅ [Init] LocalDocumentStore ready'),
          ),
          LocalExpenseStore.init().then(
            (_) => debugPrint('✅ [Init] LocalExpenseStore ready'),
          ),
        ]);
        debugPrint('✅ [Init] All Hive stores ready');
        // Sync queue can init, but processing happens in background
        return syncQueueService.init().then(
          (_) => debugPrint('✅ [Init] SyncQueue initialized'),
        );
      }),
    ]).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint(
          '⚠️ [Init] Critical dependencies (Supabase/Hive) timed out after 20s',
        );
        return []; // Return empty list to satisfy type
      },
    );

    PerformanceService.instance.logStartupMilestone('critical_services_ready');

    // 5. Initialize background services (Non-blocking)
    unawaited(_initBackgroundServices());

    unawaited(logger.cleanOldLogs());
    await logger.logLifecycle('App initialization complete');
  } catch (e, stack) {
    debugPrint('❌ [Init] Fatal error during initialization: $e');
    debugPrint('Stack trace: $stack');
    try {
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
    } catch (_) {}
  } finally {
    // ALWAYS allow the first frame and run the app, even if some services failed.
    // This prevents a permanent blank screen.
    debugPrint('🎬 [Init] Ensuring first frame is allowed...');
    widgetsBinding.allowFirstFrame();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider.value(value: localeService),
        ChangeNotifierProvider(create: (_) => ExploreProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initialize non-critical services in the background
Future<void> _initBackgroundServices() async {
  try {
    // Small delay to prioritize UI rendering
    await Future.delayed(const Duration(seconds: 1));

    PerformanceService.instance.logStartupMilestone(
      'starting_background_services',
    );

    await Future.wait([
      NotificationService.instance.init(),
      AnalyticsService.instance.init(),
      DriverRemoteConfigService.instance.init(),
      PerformanceService.instance.init(),
    ]);

    // Start geofence monitoring if user logged in with active trip
    unawaited(GeofenceService.instance.startMonitoring());

    // Initialize auth resilience for proactive token refresh
    authResilienceService.init();

    debugPrint('✅ Background services initialized');
  } catch (e, stack) {
    debugPrint('❌ Failed to init background services: $e');
    await FirebaseCrashlytics.instance.recordError(e, stack);
  }
}

// Navigation helper function
Future<void> _navigateAfterSplash(BuildContext context) async {
  // Check for force update
  final updateRequired = await VersionCheckService.instance.isUpdateRequired();
  if (updateRequired && context.mounted) {
    GoRouter.of(context).go('/force-update');
    return;
  }

  if (!context.mounted) return;

  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    GoRouter.of(context).go('/dashboard');
  } else {
    GoRouter.of(context).go('/login');
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isAuthPage =
        state.matchedLocation == '/splash' ||
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/reset-password';

    // If logged in and trying to access login/signup (but not reset-password or forgot-password), redirect to dashboard
    if (isLoggedIn &&
        (state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup')) {
      return '/dashboard';
    }

    // If not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn && !isAuthPage) {
      return '/login';
    }

    // Protect /inbox route: only accessible if connected to a company
    if (state.matchedLocation == '/inbox') {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      if (!profileProvider.isConnectedToCompany) {
        return '/dashboard';
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(
        onComplete: () => unawaited(_navigateAfterSplash(context)),
      ),
    ),
    GoRoute(
      path: '/force-update',
      builder: (context, state) => const ForceUpdatePage(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/UpdatePassword',
      builder: (context, state) => const ResetPasswordPage(),
    ),

    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: TabsShell(initialIndex: 0)),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: TabsShell(initialIndex: 3)),
      ),
    ),
    GoRoute(
      path: '/edit-profile',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: EditProfilePage()),
      ),
    ),
    GoRoute(
      path: '/privacy-security',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: PrivacySecurityPage()),
      ),
    ),
    GoRoute(
      path: '/appearance',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: AppearancePage()),
      ),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: NotificationsPage()),
      ),
    ),
    GoRoute(
      path: '/language',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: LanguagePage()),
      ),
    ),
    GoRoute(
      path: '/driver-tools',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: DriverToolsPage()),
      ),
    ),
    GoRoute(
      path: '/units-settings',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: UnitsSettingsPage()),
      ),
    ),
    GoRoute(
      path: '/add-entry',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final editingTrip = extra?['editingTrip'] as Trip?;
        final editingFuel = extra?['editingFuel'] as FuelEntry?;

        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(
            child: AddEntryPage(
              initialData: extra,
              editingTrip: editingTrip,
              editingFuel: editingFuel,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/scan-document',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(child: ScanDocumentPage(extra: extra)),
        );
      },
    ),
    GoRoute(
      path: '/explore',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: TabsShell(initialIndex: 1)),
      ),
    ),
    GoRoute(
      path: '/inbox',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: TabsShell(initialIndex: 2)),
      ),
    ),
    GoRoute(
      path: '/email-verified',
      builder: (context, state) =>
          const AuthWrapper(child: EmailVerifiedPage()),
    ),
    GoRoute(
      path: '/feedback',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: FeedbackPage()),
      ),
    ),
    GoRoute(
      path: '/records',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: RecordsListPage()),
      ),
    ),
    GoRoute(
      path: '/expenses',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: ExpensesListPage()),
      ),
    ),
    GoRoute(
      path: '/add-expense',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(
            child: AddExpensePage(
              existingExpense: extra?['expense'] as Expense?,
              tripId: extra?['tripId'] as String?,
            ),
          ),
        );
      },
    ),
  ],
);

Page<dynamic> _buildTransitionPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('maninder.co.in.milow/share');
  static bool _isProcessingShareIntent = false;

  @override
  void initState() {
    super.initState();
    _setupMethodChannelListener();
    _checkForSharedText();
    _setupDeepLinkListener();
  }

  void _setupMethodChannelListener() {
    // Listen for notifications from native side when new share intent arrives
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShareIntentReceived') {
        debugPrint('📱 Share intent received from native side');
        unawaited(_checkForSharedText());
      }
    });
  }

  void _setupDeepLinkListener() {
    // Listen for auth state changes (handles deep link redirects)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      // Skip auth redirects if we're processing a share intent
      if (_isProcessingShareIntent) {
        debugPrint('⏸️ Skipping auth redirect - processing share intent');
        return;
      }

      final event = data.event;
      final session = data.session;

      debugPrint('🔗 Auth event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        // User clicked on password reset link in email
        _router.go('/reset-password');
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        // Check current location to avoid redirecting if user is already in the app
        // This prevents overriding the share intent navigation (and other deep links)
        // when a session update/refresh occurs
        final currentPath =
            _router.routerDelegate.currentConfiguration.uri.path;
        final isAuthPage =
            currentPath == '/splash' ||
            currentPath == '/login' ||
            currentPath == '/signup' ||
            currentPath == '/forgot-password' ||
            currentPath == '/reset-password';

        if (!isAuthPage) {
          debugPrint(
            '⏸️ Already in app ($currentPath), skipping auth redirect',
          );
          return;
        }

        final user = session.user;

        // Check if this is an OAuth sign-in (Google, Apple, etc.)
        // OAuth users have identities with a provider other than 'email'
        final isOAuthSignIn =
            user.appMetadata['provider'] != 'email' &&
            user.appMetadata['provider'] != null;

        if (isOAuthSignIn) {
          // OAuth sign-in - go directly to dashboard
          debugPrint('✅ OAuth sign-in detected, going to dashboard');
          _router.go('/dashboard');
        } else if (user.emailConfirmedAt != null) {
          final confirmedTime = DateTime.parse(user.emailConfirmedAt!).toUtc();
          final now = DateTime.now().toUtc();
          // If verified within last 5 minutes, this is from email verification link
          if (now.difference(confirmedTime).inMinutes <= 5) {
            debugPrint('✅ Email verified, redirecting to login');
            // Sign out the user so they can login properly with password
            await Supabase.instance.client.auth.signOut();
            _router.go('/login');
          } else {
            // Regular email/password sign in
            _router.go('/dashboard');
          }
        } else {
          // Regular sign in without email verification
          _router.go('/dashboard');
        }
      }
    });
  }

  Future<void> _checkForSharedText() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        // Set flag to prevent auth listener from interfering
        _isProcessingShareIntent = true;
        debugPrint(
          '📥 Processing share intent: ${sharedText.substring(0, sharedText.length > 50 ? 50 : sharedText.length)}...',
        );

        // Wait a bit longer to ensure auth state is stable and app is fully initialized
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          _handleSharedText(sharedText);
        }
      }
    } catch (e) {
      debugPrint('Error getting shared text: $e');
      _isProcessingShareIntent = false;
    }
  }

  void _handleSharedText(String text) {
    // Parse the text
    final tripData = TripParserService.parse(text);

    // Navigate to Add Entry Page with data
    // Use go() instead of push() to replace current route and prevent back navigation issues
    // This ensures we always navigate to add-entry, even if already there (will refresh with new data)
    _router.go('/add-entry', extra: tripData);

    // Clear the flag after a delay to allow navigation to complete
    // This gives time for the navigation to finish before auth listener can interfere
    unawaited(
      Future.delayed(const Duration(milliseconds: 2000), () {
        _isProcessingShareIntent = false;
        debugPrint('✅ Share intent processing complete');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final localeService = Provider.of<LocaleService>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use dynamic colors from wallpaper if available, otherwise fallback to app theme
        final lightColorScheme =
            lightDynamic ?? AppTheme.lightTheme.colorScheme;
        final darkColorScheme = darkDynamic ?? AppTheme.darkTheme.colorScheme;

        return MaterialApp.router(
          title: 'Milow',
          theme: AppTheme.lightTheme.copyWith(colorScheme: lightColorScheme),
          darkTheme: AppTheme.darkTheme.copyWith(colorScheme: darkColorScheme),
          themeMode: themeService.themeMode,
          locale: localeService.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          restorationScopeId: 'milow_driver_app',
        );
      },
    );
  }
}
