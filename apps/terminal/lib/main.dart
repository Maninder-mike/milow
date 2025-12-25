import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:window_manager/window_manager.dart'; // Ensure window_manager is imported
import 'dart:io';

import 'core/providers/theme_provider.dart';
import 'core/router/router_provider.dart';
import 'features/settings/widgets/custom_about_dialog.dart';
import 'features/settings/utils/update_checker.dart';
import 'core/services/app_links_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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

  runApp(const ProviderScope(child: AdminApp()));
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
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Milow Terminal',
          menus: [
            PlatformMenuItem(
              label: 'About Milow Terminal',
              onSelected: () {
                // We need a context. Since we are using router, we use its navigator key context
                // But router.routerDelegate.navigatorKey.currentContext might be null if not built?
                // Actually GoRouter exposes it.
                // We don't have direct access to the global key here easily unless we export it or access it via router.
                // router.routerDelegate.navigatorKey is available.
                final context =
                    router.routerDelegate.navigatorKey.currentContext;
                if (context != null) {
                  showCustomAboutDialog(context);
                }
              },
            ),
            PlatformMenuItem(
              label: 'Check for Updates...',
              onSelected: () {
                final context =
                    router.routerDelegate.navigatorKey.currentContext;
                if (context != null) {
                  checkForUpdates(context);
                }
              },
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Close Window',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: true,
              ),
              onSelected: () {},
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
              ),
              onSelected: () {},
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
              onSelected: () {},
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Cut',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Copy',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Paste',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Select All',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                  onSelected: null,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItem(
              label: 'Minimize',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyM,
                meta: true,
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
          fontFamily: 'Segoe UI Variable',
        ),
        darkTheme: FluentThemeData(
          accentColor: SystemTheme.accentColor.accent.toAccentColor(),
          brightness: Brightness.dark,
          fontFamily: 'Segoe UI Variable',
        ),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
