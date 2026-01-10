import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/providers/profile_provider.dart';
import 'package:terminal/features/auth/presentation/pages/login_page.dart';
import 'package:terminal/features/auth/presentation/pages/sign_up_page.dart';
import 'package:terminal/features/auth/presentation/pages/terms_page.dart';
import 'package:terminal/features/auth/presentation/pages/privacy_policy_page.dart';
import 'package:terminal/features/auth/presentation/pages/reset_password_page.dart';
import 'package:terminal/features/auth/presentation/pending_verification_page.dart';
import 'package:terminal/features/auth/presentation/pages/access_denied_page.dart'; // [NEW]

import 'package:terminal/features/dashboard/dashboard_shell.dart';
import 'package:terminal/features/inbox/inbox_view.dart';
import 'package:terminal/features/users/presentation/users_page.dart';
import 'package:terminal/features/users/presentation/user_form_page.dart';
import 'package:terminal/features/drivers/presentation/drivers_page.dart';
import 'package:terminal/features/settings/settings_page.dart';
import 'package:terminal/features/settings/users_roles_groups_page.dart';
import 'package:terminal/features/settings/role_configuration_page.dart';
import 'package:terminal/features/settings/profile_page.dart';
import 'package:terminal/features/dashboard/screens/overview_page.dart';
import 'package:terminal/features/dashboard/screens/entity_placeholder_page.dart';
import 'package:terminal/features/dashboard/screens/customer/customer_page.dart';
import 'package:terminal/features/dashboard/screens/pickup/pickup_page.dart';
import 'package:terminal/features/dashboard/screens/deliver/delivery_page.dart';
import 'package:terminal/features/dashboard/screens/vehicles/vehicles_page.dart';
import 'package:terminal/features/dashboard/screens/vehicles/vehicle_status_page.dart';
import 'package:terminal/features/dispatch/presentation/pages/dispatch_page.dart';
import 'package:terminal/features/dispatch/presentation/pages/loads_page.dart'; // [NEW] import
import 'package:terminal/features/dispatch/presentation/pages/quotes_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const AccessDeniedPage(),
      ),
      GoRoute(
        path: '/pending-verification',
        builder: (context, state) => const PendingVerificationPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpPage()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
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
          GoRoute(
            path: '/inbox',
            builder: (context, state) => const InboxView(),
          ),
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
            path: '/settings/users-roles',
            builder: (context, state) => const UsersRolesGroupsPage(),
          ),
          GoRoute(
            path: '/settings/roles/:roleId',
            builder: (context, state) {
              final roleId = state.pathParameters['roleId'] ?? '';
              return RoleConfigurationPage(roleId: roleId);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/customer',
            builder: (context, state) => const CustomerPage(),
          ),
          GoRoute(
            path: '/pickup',
            builder: (context, state) => const PickUpPage(),
          ),
          GoRoute(
            path: '/deliver',
            builder: (context, state) => const DeliveryPage(),
          ),
          GoRoute(
            path: '/vehicles',
            builder: (context, state) => const VehiclesPage(),
          ),
          GoRoute(
            path: '/vehicles/status',
            builder: (context, state) {
              final vehicle = state.extra as Map<String, dynamic>? ?? {};
              return VehicleStatusPage(vehicle: vehicle);
            },
          ),
          GoRoute(
            path: '/highway-dispatch',
            builder: (context, state) => const LoadsPage(),
          ),
          GoRoute(
            path: '/quotes',
            builder: (context, state) => const QuotesPage(),
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
          GoRoute(
            path: '/dispatch',
            builder: (context, state) => const DispatchPage(),
          ),
        ],
      ),
    ],
  );
});

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isPasswordRecovery = false;

  RouterNotifier(this._ref) {
    _ref.listen(profileProvider, (previous, next) => notifyListeners());
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else if (event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
        _ref.invalidate(profileProvider);
      } else if (event == AuthChangeEvent.signedIn) {
        _ref.invalidate(profileProvider);
      }
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final location = state.matchedLocation;

    if (_isPasswordRecovery) return '/reset-password';

    final isPublicPage =
        location == '/login' ||
        location == '/signup' ||
        location == '/reset-password' ||
        location == '/terms' ||
        location == '/privacy' ||
        location == '/access-denied';

    if (!isLoggedIn && !isPublicPage) return '/login';

    if (isLoggedIn) {
      final profileState = _ref.read(profileProvider);

      if (profileState.isLoading) return null;

      final profile = profileState.value;
      if (profile != null) {
        final role = profile['role'] as String? ?? 'pending';
        final isVerified = profile['is_verified'] as bool? ?? false;

        if (role == 'driver') {
          if (location != '/access-denied') {
            return '/access-denied';
          }
          return null;
        }

        if ((!isVerified || role == 'pending') &&
            location != '/pending-verification') {
          return '/pending-verification';
        }

        if (isVerified &&
            role != 'pending' &&
            location == '/pending-verification') {
          return '/dashboard';
        }
      }

      if (location == '/login') {
        return '/dashboard';
      }
    }
    return null;
  }
}
