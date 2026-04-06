import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:animations/animations.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow/core/theme/app_theme.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/theme_service.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/messaging_provider.dart';
import 'package:milow/core/services/locale_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/services/announcements_provider.dart';
import 'package:milow/core/services/check_call_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:milow/core/services/trip_parser_service.dart';
import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/local_load_document_store.dart';
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
import 'package:milow/features/documents/presentation/pages/documents_page.dart';
import 'package:milow/features/documents/presentation/pages/shared_documents_page.dart';

import 'package:milow/features/loads/presentation/pages/available_loads_page.dart';
import 'package:milow/features/loads/presentation/pages/load_details_page.dart';

import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/expenses/presentation/pages/expenses_list_page.dart';
import 'package:milow/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:milow/features/settings/presentation/pages/units_settings_page.dart';
import 'package:milow/features/dashboard/presentation/pages/driver_tools_page.dart';
// Note: tab pages are hosted via TabsShell
import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/core/widgets/tabs_shell.dart';
import 'package:milow/core/widgets/splash_screen.dart';

import 'package:milow/features/inspections/presentation/providers/inspection_provider.dart';
import 'package:milow/features/inspections/data/repositories/inspection_repository_impl.dart';
import 'package:milow/features/inspections/presentation/pages/inspections_page.dart';
import 'package:milow/features/inspections/presentation/pages/inspection_form_page.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/location/location_tracking_service.dart';
import 'package:milow/core/services/location/location_controller.dart';
import 'package:milow/core/services/location/location_repository.dart';

import 'package:milow/features/inbox/presentation/pages/chat_detail_page.dart';
import 'package:milow/features/auth/presentation/pages/email_verified_page.dart';
import 'package:milow/features/auth/presentation/pages/reset_password_page.dart';
import 'package:milow/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';

Future<void> main() async {
  // Wrap in runZonedGuarded to catch all async errors (including those outside Flutter context)
  // and ensure ensureInitialized() is called within the same zone as runApp()
  await runZonedGuarded(
    () async {
      final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      // Keep native splash screen up until we're ready
      widgetsBinding.deferFirstFrame();

      PreferencesService? prefService;

      // 1. Critical Base Services (Blocking)
      try {
        // Let sqlite3_flutter_libs handle the architecture-specific loading automatically
        // No manual override needed for SQLite on Android when using sqlite3_flutter_libs
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
          final isNetworkError =
              errorStr.contains('socketexception') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('clientexception') ||
              errorStr.contains('authretryablefetchexception') ||
              errorStr.contains('connection refused') ||
              errorStr.contains('network is unreachable');

          if (isNetworkError) {
            debugPrint('📵 Transient network error (non-fatal): $error');
            FirebaseCrashlytics.instance.recordError(
              error,
              stack,
              fatal: false,
              reason: 'PlatformDispatcher: Transient Network Error',
            );
            return true;
          }

          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: true,
            reason: 'PlatformDispatcher.onError',
          );
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
            await Future.wait<dynamic>([
              LocalProfileStore.init().then(
                (_) => debugPrint('✅ [Init] LocalProfileStore ready'),
              ),
              Future.wait([
                LocalDocumentStore.init().then(
                  (_) => debugPrint('[Main] LocalDocumentStore init done'),
                ),
                LocalLoadDocumentStore.init().then(
                  (_) => debugPrint('[Main] LocalLoadDocumentStore init done'),
                ),
              ]),
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

        PerformanceService.instance.logStartupMilestone(
          'critical_services_ready',
        );

        // 5. Initialize background services (Non-blocking)
        unawaited(_initBackgroundServices());

        unawaited(logger.cleanOldLogs());
        final service = await PreferencesService.init();
        prefService = service;
        await logger.logLifecycle('App initialization complete');
      } catch (e, stack) {
        debugPrint('❌ [Init] Fatal error during initialization: $e');
        debugPrint('Stack trace: $stack');
        try {
          await FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        } catch (_) {}
      } finally {
        // ALWAYS allow the first frame and run the app, even if some services failed.
        // This prevents a permanent blank screen.
        debugPrint('🎬 [Init] Ensuring first frame is allowed...');
        widgetsBinding.allowFirstFrame();
      }

      debugPrint('🚀 [Init] Running App...');
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider.value(value: localeService),
            ChangeNotifierProvider(create: (_) => ExploreProvider()),
            ChangeNotifierProvider(
              create: (_) => InspectionProvider(
                InspectionRepositoryImpl(
                  driverDatabase,
                  CoreNetworkClient(Supabase.instance.client),
                ),
              ),
            ),
            Provider(create: (_) => LocationTrackingService(driverDatabase)),
            ChangeNotifierProvider(
              create: (context) => 
                  LocationController(context.read<LocationTrackingService>()),
            ),
            Provider(
              create: (_) =>
                  LocationRepository(driverDatabase, Supabase.instance.client),
            ),
            ChangeNotifierProvider(
              create: (_) => MessagingProvider(driverDatabase)..init(),
            ),
            ChangeNotifierProvider(create: (_) => AnnouncementsProvider()),
            ChangeNotifierProvider(create: (_) => CheckCallService()),
            if (prefService != null)
              ChangeNotifierProvider.value(value: prefService),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('🔥 [runZonedGuarded] Caught unhandled error: $error');

      final errorStr = error.toString().toLowerCase();
      final isNetworkError =
          errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('authretryablefetchexception') ||
          errorStr.contains('connection refused') ||
          errorStr.contains('network is unreachable') ||
          errorStr.contains('websocketchannelexception');

      if (isNetworkError) {
        debugPrint('📵 Transient network error (non-fatal): $error');
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: false,
          reason: 'runZonedGuarded: Transient Network Error',
        );
      } else {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
          reason: 'runZonedGuarded unhandled error',
        );
      }
    },
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

    // Start location tracking if user is logged in
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final driverId = session.user.id;
      final trackingService = LocationTrackingService(driverDatabase);
      final locationRepo = LocationRepository(
        driverDatabase,
        Supabase.instance.client,
      );

      unawaited(trackingService.startTracking(driverId: driverId));
      locationRepo.startSyncTimer();
    }

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
      path: '/load-details/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(child: LoadDetailsPage(loadId: id)),
        );
      },
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
          AuthWrapper(child: DocumentsPage(extra: extra)),
        );
      },
    ),
    GoRoute(
      path: '/shared-documents',
      pageBuilder: (context, state) {
        final companyId = state.extra as String;
        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(child: SharedDocumentsPage(companyId: companyId)),
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
    GoRoute(
      path: '/inspections',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: InspectionsPage()),
      ),
      routes: [
        GoRoute(
          path: 'new',
          pageBuilder: (context, state) => _buildTransitionPage(
            context,
            state,
            const AuthWrapper(child: InspectionFormPage()),
          ),
        ),
        GoRoute(
          path: 'edit/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id'];
            return _buildTransitionPage(
              context,
              state,
              AuthWrapper(child: InspectionFormPage(inspectionId: id)),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/chat',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _buildTransitionPage(
          context,
          state,
          AuthWrapper(
            child: ChatDetailPage(
              partnerId: extra['partnerId'] as String?,
              partnerName: extra['partnerName'] as String,
              partnerAvatarUrl: extra['partnerAvatarUrl'] as String?,
              loadId: extra['loadId'] as String?,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/available-loads',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: AvailableLoadsPage()),
      ),
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

    // Pass router to notification service for deep linking
    notificationService.setRouter(_router);
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

        // For dark mode, we want dynamic ACCENTS (primary/secondary) but fixed PREMIUM SURFACES.
        // If darkDynamic is present, use it but force our slate surfaces back in.
        final effectiveDarkScheme =
            (darkDynamic ?? AppTheme.darkTheme.colorScheme).copyWith(
              surface: DesignTokens.dark.surfaceContainer,
              onSurface: DesignTokens.dark.textPrimary,
              surfaceContainer: DesignTokens.dark.surfaceContainer,
              surfaceContainerHigh: DesignTokens.dark.surfaceContainerHigh,
              // Ensure semantic colors are consistent
              error: DesignTokens.dark.error,
              errorContainer: DesignTokens.dark.errorContainer,
              outline: DesignTokens.dark.subtleBorderColor,
              outlineVariant: DesignTokens.dark.subtleBorderColor,
            );

        return MaterialApp.router(
          title: 'Milow',
          theme: AppTheme.lightTheme.copyWith(colorScheme: lightColorScheme),
          darkTheme: AppTheme.darkTheme.copyWith(
            colorScheme: effectiveDarkScheme,
            scaffoldBackgroundColor: DesignTokens.dark.scaffoldAltBackground,
          ),
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
