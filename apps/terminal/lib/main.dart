import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'core/providers/theme_provider.dart';
import 'core/router/router_provider.dart';
import 'features/settings/widgets/custom_about_dialog.dart';
import 'features/settings/utils/update_checker.dart';
import 'core/services/app_links_service.dart';
import 'core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/shared_preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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

    await AppLinksService().initialize();
    await NotificationService().init();
  } catch (e) {
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
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AdminApp(),
    ),
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

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            PlatformMenuItem(label: 'Milow Terminal Help', onSelected: () {}),
          ],
        ),
      ],
      child: FluentApp.router(
        title: 'Milow Terminal',
        theme: FluentThemeData(
          accentColor: SystemTheme.accentColor.accent.toAccentColor(),
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
          fontFamily: GoogleFonts.outfit().fontFamily,
        ),
        darkTheme: FluentThemeData(
          accentColor: SystemTheme.accentColor.accent.toAccentColor(),
          brightness: Brightness.dark,
          visualDensity: VisualDensity.standard,
          fontFamily: GoogleFonts.outfit().fontFamily,
        ),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
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
