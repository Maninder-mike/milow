import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/theme/app_theme.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/theme_service.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/services/messaging_provider.dart';
import 'package:milow/core/services/locale_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/services/announcements_provider.dart';
import 'package:milow/core/services/check_call_service.dart';
import 'package:flutter/services.dart';

import 'package:milow/core/services/trip_parser_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/routing/app_router.dart';
import 'package:milow/core/services/app_initializer.dart';
import 'package:milow/l10n/app_localizations.dart';

import 'package:milow/features/trips/presentation/widgets/share_confirmation_sheet.dart';
import 'package:milow/core/providers/unit_suggestion_provider.dart';

import 'package:milow/features/inspections/presentation/providers/inspection_provider.dart';
import 'package:milow/features/inspections/data/repositories/inspection_repository_impl.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/location/location_tracking_service.dart';
import 'package:milow/core/services/location/location_controller.dart';
import 'package:milow/core/services/location/location_repository.dart';
import 'package:milow/features/explore/presentation/providers/explore_provider.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      widgetsBinding.deferFirstFrame();

      PreferencesService? prefService;

      try {
        prefService = await AppInitializer.initCriticalServices();
      } finally {
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
            ChangeNotifierProvider(
              create: (_) => AnnouncementsProvider(driverDatabase),
            ),
            ChangeNotifierProvider(create: (_) => CheckCallService()),
            if (prefService != null) ...[
              ChangeNotifierProvider.value(value: prefService),
              ChangeNotifierProvider(
                create: (context) => UnitSuggestionProvider(prefService!),
              ),
            ],
          ],
          child: const MyApp(),
        ),
      );
    },
    AppInitializer.handleUncaughtError,
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

    notificationService.setRouter(appRouter);
  }

  void _setupMethodChannelListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShareIntentReceived') {
        debugPrint('📱 Share intent received from native side');
        unawaited(_checkForSharedText());
      }
    });
  }

  void _setupDeepLinkListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_isProcessingShareIntent) {
        debugPrint('⏸️ Skipping auth redirect - processing share intent');
        return;
      }

      final event = data.event;
      final session = data.session;

      debugPrint('🔗 Auth event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        appRouter.go('/reset-password');
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        final currentPath =
            appRouter.routerDelegate.currentConfiguration.uri.path;
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

        final isOAuthSignIn =
            user.appMetadata['provider'] != 'email' &&
            user.appMetadata['provider'] != null;

        if (isOAuthSignIn) {
          debugPrint('✅ OAuth sign-in detected, going to dashboard');
          appRouter.go('/dashboard');
        } else if (user.emailConfirmedAt != null) {
          final confirmedTime = DateTime.parse(user.emailConfirmedAt!).toUtc();
          final now = DateTime.now().toUtc();
          if (now.difference(confirmedTime).inMinutes <= 5) {
            debugPrint('✅ Email verified, redirecting to login');
            await Supabase.instance.client.auth.signOut();
            appRouter.go('/login');
          } else {
            appRouter.go('/dashboard');
          }
        } else {
          appRouter.go('/dashboard');
        }
      }
    });
  }

  Future<void> _checkForSharedText() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        _isProcessingShareIntent = true;
        debugPrint(
          '📥 Processing share intent: ${sharedText.substring(0, sharedText.length > 50 ? 50 : sharedText.length)}...',
        );

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
    final tripData = TripParserService.parse(text);

    final context = navigatorKey.currentContext;
    if (context != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ShareConfirmationSheet(
          data: tripData,
          onConfirm: () {
            Navigator.pop(context);
            appRouter.go('/add-entry', extra: tripData);
          },
          onCancel: () {
            Navigator.pop(context);
            _isProcessingShareIntent = false;
          },
        ),
      );
    }

    unawaited(
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_isProcessingShareIntent) {
          _isProcessingShareIntent = false;
        }
        debugPrint('✅ Share intent processing initiated');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final localeService = Provider.of<LocaleService>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme =
            lightDynamic ?? AppTheme.lightTheme.colorScheme;

        final effectiveDarkScheme =
            (darkDynamic ?? AppTheme.darkTheme.colorScheme).copyWith(
              surface: DesignTokens.dark.surfaceContainer,
              onSurface: DesignTokens.dark.textPrimary,
              surfaceContainer: DesignTokens.dark.surfaceContainer,
              surfaceContainerHigh: DesignTokens.dark.surfaceContainerHigh,
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
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          restorationScopeId: 'milow_driver_app',
        );
      },
    );
  }
}
