import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'firebase_options.dart';

import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/router_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'features/shared/widgets/shortcuts_reference_dialog.dart';
import 'features/settings/widgets/custom_about_dialog.dart';
import 'features/settings/utils/update_checker.dart';
import 'core/services/app_links_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/version_check_service.dart';
import 'features/shared/widgets/update_dialog.dart';
import 'core/services/window_persistence_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/shared_preferences_provider.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await windowManager.ensureInitialized();

      // Initialize Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Initialize Remote Config & Performance (all platforms)
        try {
          // Remote Config
          final remoteConfig = FirebaseRemoteConfig.instance;
          await remoteConfig.setConfigSettings(
            RemoteConfigSettings(
              fetchTimeout: const Duration(minutes: 1),
              minimumFetchInterval: const Duration(hours: 12),
            ),
          );
          await remoteConfig.setDefaults(const {
            "welcome_message": "Welcome to Milow Terminal",
            "terminal_min_version": "",
            "terminal_latest_version": "",
            "windows_store_url": "",
            "macos_download_url":
                "https://github.com/Maninder-mike/milow/releases",
          });
          // Fetch and activate (fire and forget to not block startup too long)
          unawaited(remoteConfig.fetchAndActivate());

          // Performance Monitoring
          FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
        } catch (e) {
          AppLogger.warning(
            'Firebase Remote Config/Performance init failed',
            context: {'error': e.toString()},
          );
        }
      } catch (e) {
        AppLogger.error('Firebase initialization failed', error: e);
        // Continue execution checking .env and other services
      }

      // Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      try {
        await dotenv.load(fileName: ".env");

        final supabaseUrl = SupabaseConstants.supabaseUrl;
        final supabaseAnonKey = SupabaseConstants.supabaseAnonKey;

        if (supabaseUrl.contains('your-project-id') ||
            supabaseAnonKey.contains('your_anon_key')) {
          runApp(
            const ConfigurationErrorApp(
              error:
                  'Please configure apps/terminal/.env with valid Supabase credentials.',
            ),
          );
          return;
        }

        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

        // Initialize AppLogger with context
        AppLogger.initialize(appVersion: '0.0.3+27');
        AppLogger.info('Supabase initialized successfully.');

        await AppLinksService().initialize();
        await NotificationService().init();
      } catch (e) {
        AppLogger.fatal('Initialization failed', error: e);
        runApp(ConfigurationErrorApp(error: 'Initialization failed: $e'));
        return;
      }

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        WindowOptions windowOptions = const WindowOptions(
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          // Initialize persistence service
          final persistenceService = WindowPersistenceService(prefs);

          // Restore saved state (or default to maximized if first run)
          await persistenceService.restoreState();

          // Fallback: Maximize on first run if no state saved
          if (!prefs.containsKey('window_maximized') &&
              !prefs.containsKey('window_width')) {
            await windowManager.maximize();
          }

          await windowManager.show();
          await windowManager.focus();
        });
      }

      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          // Enable Root Restoration Scope for state restoration
          child: const RootRestorationScope(
            restorationId: 'milow_terminal_root',
            child: AdminApp(),
          ),
        ),
      );
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class ConfigurationErrorApp extends StatelessWidget {
  final String error;
  const ConfigurationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      home: ScaffoldPage(
        content: Center(
          child: ContentDialog(
            title: const Text('Configuration Error'),
            content: Text(error),
            actions: [
              Button(child: const Text('Exit'), onPressed: () => exit(1)),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  @override
  void initState() {
    super.initState();
    // Check for updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  Future<void> _checkVersion() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Ensure we have the latest config before checking
      await remoteConfig.fetchAndActivate();

      final versionService = VersionCheckService(remoteConfig);
      final status = await versionService.checkUpdateStatus();

      if (!mounted) return;

      if (status == UpdateStatus.forceUpdate) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const UpdateDialog(isForceUpdate: true),
        );
      } else if (status == UpdateStatus.optionalUpdate) {
        // Optional updates shouldn't block, so we don't await
        showDialog(
          context: context,
          builder: (context) => const UpdateDialog(isForceUpdate: false),
        );
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize system notifications listener
    ref.watch(systemNotificationProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Milow Terminal',
          menus: _buildAppMenuItems(router),
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Close Window',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: Platform.isMacOS,
                control: !Platform.isMacOS,
              ),
              onSelected: () async {
                await windowManager.close();
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: Platform.isMacOS,
                control: !Platform.isMacOS,
              ),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: Platform.isMacOS,
                control: !Platform.isMacOS,
                shift: true,
              ),
              onSelected: () {},
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Cut',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: Platform.isMacOS,
                    control: !Platform.isMacOS,
                    shift: true,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Copy',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: Platform.isMacOS,
                    control: !Platform.isMacOS,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Paste',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: Platform.isMacOS,
                    control: !Platform.isMacOS,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Select All',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: Platform.isMacOS,
                    control: !Platform.isMacOS,
                  ),
                  onSelected: null,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(label: 'View', menus: _buildViewMenuItems(ref)),
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItem(
              label: 'Minimize',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyM,
                meta: Platform.isMacOS,
                control: !Platform.isMacOS,
              ),
              onSelected: () async {
                await windowManager.minimize();
              },
            ),
            PlatformMenuItem(
              label: 'Zoom',
              onSelected: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.restore();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Tools',
          menus: [
            PlatformMenuItem(label: 'Master Entry', onSelected: () {}),
            PlatformMenuItem(label: 'Day to Day Entry', onSelected: () {}),
            PlatformMenuItem(label: 'Modify Entries', onSelected: () {}),
            PlatformMenuItem(label: 'Delete Entries', onSelected: () {}),
            PlatformMenuItem(label: 'Fuel-Tax (IFTA)', onSelected: () {}),
            PlatformMenuItem(label: 'GL Module', onSelected: () {}),
            PlatformMenuItem(label: 'CSA/FAST Module', onSelected: () {}),
            PlatformMenuItem(label: 'Master Invoice', onSelected: () {}),
          ],
        ),
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: 'Milow Terminal Help',
              onSelected: () {
                launchUrl(
                  Uri.parse('https://github.com/Maninder-mike/milow/wiki'),
                );
              },
            ),
            PlatformMenuItem(
              label: 'Keyboard Shortcuts Reference',
              shortcut: const CharacterActivator('k', meta: true),
              onSelected: () {
                final context =
                    router.routerDelegate.navigatorKey.currentContext;
                if (context != null) {
                  showDialog(
                    context: context,
                    builder: (context) => const ShortcutsReferenceDialog(),
                  );
                }
              },
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'View License',
                  onSelected: () {
                    launchUrl(
                      Uri.parse(
                        'https://www.maninder.co.in/milow/termsandconditions',
                      ),
                    );
                  },
                ),
                PlatformMenuItem(
                  label: 'Privacy Statement',
                  onSelected: () {
                    launchUrl(
                      Uri.parse(
                        'https://www.maninder.co.in/milow/privacypolicy',
                      ),
                    );
                  },
                ),
              ],
            ),
            PlatformMenuItem(
              label: 'Report Issue',
              onSelected: () {
                launchUrl(
                  Uri.parse('https://github.com/Maninder-mike/milow/issues'),
                );
              },
            ),
            PlatformMenuItem(
              label: 'Test Crash',
              onSelected: () => FirebaseCrashlytics.instance.crash(),
            ),
          ],
        ),
      ],
      child: FluentApp.router(
        title: 'Milow Terminal',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        // State Restoration ID for the app instance
        restorationScopeId: 'terminal_app',
      ),
    );
  }

  List<PlatformMenuItem> _buildAppMenuItems(GoRouter router) {
    final items = <PlatformMenuItem>[
      PlatformMenuItem(
        label: 'About Milow Terminal',
        onSelected: () {
          final context = router.routerDelegate.navigatorKey.currentContext;
          if (context != null) {
            showCustomAboutDialog(context);
          }
        },
      ),
      PlatformMenuItem(
        label: 'Check for Updates...',
        onSelected: () {
          final context = router.routerDelegate.navigatorKey.currentContext;
          if (context != null) {
            checkForUpdates(context);
          }
        },
      ),
    ];

    // Only add quit menu item on platforms that support it (macOS)
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.quit)) {
      items.add(
        const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
      );
    } else {
      // Add a manual exit option for Windows/Linux
      items.add(
        PlatformMenuItem(
          label: 'Exit',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyQ,
            control: true,
          ),
          onSelected: () => exit(0),
        ),
      );
    }

    return items;
  }

  List<PlatformMenuItem> _buildViewMenuItems(WidgetRef ref) {
    final items = <PlatformMenuItem>[];

    // Theme Submenu
    items.add(
      PlatformMenu(
        label: 'Theme',
        menus: [
          PlatformMenuItem(
            label: 'System',
            onSelected: () {
              ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
            },
          ),
          PlatformMenuItem(
            label: 'Light',
            onSelected: () {
              ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
            },
          ),
          PlatformMenuItem(
            label: 'Dark',
            onSelected: () {
              ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
            },
          ),
        ],
      ),
    );

    // Only add toggleFullScreen on platforms that support it (macOS)
    if (PlatformProvidedMenuItem.hasMenu(
      PlatformProvidedMenuItemType.toggleFullScreen,
    )) {
      items.add(
        const PlatformProvidedMenuItem(
          type: PlatformProvidedMenuItemType.toggleFullScreen,
        ),
      );
    } else {
      // Add a manual fullscreen toggle for Windows/Linux
      items.add(
        PlatformMenuItem(
          label: 'Toggle Full Screen',
          shortcut: const SingleActivator(LogicalKeyboardKey.f11),
          onSelected: () async {
            final isFullScreen = await windowManager.isFullScreen();
            await windowManager.setFullScreen(!isFullScreen);
          },
        ),
      );
    }

    return items;
  }
}
