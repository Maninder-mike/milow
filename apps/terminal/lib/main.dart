import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_page.dart';
import 'features/auth/sign_up_page.dart';
import 'features/auth/terms_page.dart';
import 'features/auth/privacy_policy_page.dart';
import 'core/providers/theme_provider.dart';
import 'features/dashboard/dashboard_shell.dart';
import 'features/inbox/inbox_view.dart';
import 'features/users/presentation/users_page.dart';
import 'features/users/presentation/user_form_page.dart';
import 'features/drivers/presentation/drivers_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/profile_page.dart';
import 'features/dashboard/screens/overview_page.dart';
import 'features/dashboard/screens/entity_placeholder_page.dart';
import 'features/settings/widgets/custom_about_dialog.dart';
import 'features/settings/utils/update_checker.dart';

import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'core/router/router_refresh_stream.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final location = state.matchedLocation;

    final isPublicPage =
        location == '/login' ||
        location == '/signup' ||
        location == '/terms' ||
        location == '/privacy';

    if (!isLoggedIn && !isPublicPage) return '/login';
    if (isLoggedIn && location == '/login') return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
    GoRoute(path: '/terms', builder: (context, state) => const TermsPage()),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return DashboardShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const OverviewPage(),
        ),
        GoRoute(path: '/inbox', builder: (context, state) => const InboxView()),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const UserFormPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        // New Entity Routes
        GoRoute(
          path: '/customer',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Customer'),
        ),
        GoRoute(
          path: '/pickup',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Pick Up'),
        ),
        GoRoute(
          path: '/deliver',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Deliver'),
        ),
        GoRoute(
          path: '/highway-dispatch',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Highway Dispatch'),
        ),
        GoRoute(
          path: '/driver-hos',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Driver HOS'),
        ),
        GoRoute(
          path: '/location',
          builder: (context, state) =>
              const EntityPlaceholderPage(title: 'Location'),
        ),
        GoRoute(
          path: '/drivers',
          builder: (context, state) => const DriversPage(),
        ),
      ],
    ),
  ],
);

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Milow Terminal',
          menus: [
            PlatformMenuItem(
              label: 'About Milow Terminal',
              onSelected: () {
                final context = _rootNavigatorKey.currentContext;
                if (context != null) {
                  showCustomAboutDialog(context);
                }
              },
            ),
            PlatformMenuItem(
              label: 'Check for Updates...',
              onSelected: () {
                final context = _rootNavigatorKey.currentContext;
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
        themeMode: ref.watch(themeProvider),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
