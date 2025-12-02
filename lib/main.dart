import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow/core/theme/app_theme.dart';
import 'package:milow/core/constants/supabase_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/theme_service.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:flutter/services.dart';
import 'package:milow/core/services/trip_parser_service.dart';
import 'package:milow/core/services/local_profile_store.dart';

// Placeholder imports - will be replaced with actual pages
import 'package:milow/features/auth/presentation/pages/login_page.dart';
import 'package:milow/features/auth/presentation/pages/sign_up_page.dart';
import 'package:milow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:milow/features/settings/presentation/pages/settings_page.dart';
import 'package:milow/features/settings/presentation/pages/privacy_security_page.dart';
import 'package:milow/features/settings/presentation/pages/appearance_page.dart';
import 'package:milow/features/settings/presentation/pages/edit_profile_page.dart';
import 'package:milow/features/settings/presentation/pages/notifications_page.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/features/explore/presentation/pages/explore_page.dart';
import 'package:milow/features/inbox/presentation/pages/inbox_page.dart';
import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/features/auth/presentation/pages/email_verified_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Hive for local caching
  await Hive.initFlutter();
  await LocalProfileStore.init();

  // Validate Supabase environment quickly to avoid silent issues
  final supabaseUrl = SupabaseConstants.supabaseUrl;
  final supabaseAnon = SupabaseConstants.supabaseAnonKey;
  if (supabaseUrl.isEmpty || supabaseAnon.isEmpty) {
    debugPrint(
      '[Milow] WARNING: Supabase env not set. Check .env for NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnon);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isLoggingIn =
        state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    // If logged in and trying to access login/signup, redirect to dashboard
    if (isLoggedIn && isLoggingIn) {
      return '/dashboard';
    }

    // If not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AuthWrapper(child: DashboardPage()),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const AuthWrapper(child: SettingsPage()),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const AuthWrapper(child: EditProfilePage()),
    ),
    GoRoute(
      path: '/privacy-security',
      builder: (context, state) =>
          const AuthWrapper(child: PrivacySecurityPage()),
    ),
    GoRoute(
      path: '/appearance',
      builder: (context, state) => const AuthWrapper(child: AppearancePage()),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) =>
          const AuthWrapper(child: NotificationsPage()),
    ),
    GoRoute(
      path: '/add-entry',
      builder: (context, state) {
        final initialData = state.extra as Map<String, dynamic>?;
        return AuthWrapper(child: AddEntryPage(initialData: initialData));
      },
    ),
    GoRoute(
      path: '/explore',
      builder: (context, state) => const AuthWrapper(child: ExplorePage()),
    ),
    GoRoute(
      path: '/inbox',
      builder: (context, state) => const AuthWrapper(child: InboxPage()),
    ),
    GoRoute(
      path: '/email-verified',
      builder: (context, state) =>
          const AuthWrapper(child: EmailVerifiedPage()),
    ),
  ],
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('maninder.co.in.milow/share');

  @override
  void initState() {
    super.initState();
    _checkForSharedText();
  }

  Future<void> _checkForSharedText() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        // Wait a bit for the app to fully initialize
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleSharedText(sharedText);
        });
      }
    } catch (e) {
      debugPrint('Error getting shared text: $e');
    }
  }

  void _handleSharedText(String text) {
    // Parse the text
    final tripData = TripParserService.parse(text);

    // Navigate to Add Entry Page with data
    // We need to ensure navigation happens after the app is built or use the router directly
    // Since _router is global, we can use it.
    _router.push('/add-entry', extra: tripData);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp.router(
      title: 'Milow',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
