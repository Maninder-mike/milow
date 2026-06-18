import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/locale_service.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/performance_service.dart';
import 'package:milow/core/services/secure_local_storage.dart';
import 'package:milow/core/services/local_profile_store.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/local_load_document_store.dart';
import 'package:milow/core/services/local_expense_store.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/models/sync_operation.dart';

import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/services/analytics_service.dart';
import 'package:milow/core/services/driver_remote_config_service.dart';
import 'package:milow/core/services/geofence_service.dart';
import 'package:milow/core/services/auth_resilience_service.dart';
import 'package:milow/core/services/location/location_tracking_service.dart';
import 'package:milow/core/services/location/location_repository.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';

class AppInitializer {
  static Future<PreferencesService?> initCriticalServices() async {
    PreferencesService? prefService;

    try {
      debugPrint('🚀 [Init] Initializing Firebase...');
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ [Init] Firebase initialization timed out after 10s');
          throw TimeoutException('Firebase initialization timed out');
        },
      );
      debugPrint('✅ [Init] Firebase initialized');

      await PerformanceService.instance.startColdStartTrace();
      PerformanceService.instance.logStartupMilestone('app_launched');

      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (error is AuthException &&
            error.code == 'refresh_token_already_used') {
          debugPrint('⚠️ Refresh token already used. Signing out...');
          Supabase.instance.client.auth.signOut();
          return true;
        }

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

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );

      debugPrint('🚀 [Init] Loading environment and base services...');
      await Future.wait([
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        dotenv.load(fileName: '.env').then((_) => debugPrint('✅ [Init] .env loaded')),
        logger.init().then((_) => debugPrint('✅ [Init] Logger initialized')),
        localeService.loadLocale().then((_) => debugPrint('✅ [Init] Locale loaded')),
        connectivityService.init().then((_) => debugPrint('✅ [Init] Connectivity initialized')),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ [Init] Base services initialization timed out after 15s');
          return [];
        },
      );

      PerformanceService.instance.logStartupMilestone('environment_loaded');

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
          await Future.wait<dynamic>([
            LocalProfileStore.init().then((_) => debugPrint('✅ [Init] LocalProfileStore ready')),
            Future.wait([
              LocalDocumentStore.init().then((_) => debugPrint('[Main] LocalDocumentStore init done')),
              LocalLoadDocumentStore.init().then((_) => debugPrint('[Main] LocalLoadDocumentStore init done')),
            ]),
            LocalExpenseStore.init().then((_) => debugPrint('✅ [Init] LocalExpenseStore ready')),
          ]);
          debugPrint('✅ [Init] All Hive stores ready');
          return syncQueueService.init().then((_) => debugPrint('✅ [Init] SyncQueue initialized'));
        }),
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('⚠️ [Init] Critical dependencies (Supabase/Hive) timed out after 20s');
          return [];
        },
      );

      PerformanceService.instance.logStartupMilestone('critical_services_ready');

      unawaited(initBackgroundServices());

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
    }
    return prefService;
  }

  static Future<void> initBackgroundServices() async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      PerformanceService.instance.logStartupMilestone('starting_background_services');

      await Future.wait([
        NotificationService.instance.init(),
        AnalyticsService.instance.init(),
        DriverRemoteConfigService.instance.init(),
        PerformanceService.instance.init(),
      ]);

      unawaited(GeofenceService.instance.startMonitoring());

      authResilienceService.init();

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

  static void handleUncaughtError(Object error, StackTrace stack) {
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
  }
}
