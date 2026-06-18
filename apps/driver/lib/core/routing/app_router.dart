import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animations/animations.dart';
import 'dart:async';

// Import all required pages
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
import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/core/widgets/tabs_shell.dart';
import 'package:milow/core/widgets/splash_screen.dart';
import 'package:milow/features/inspections/presentation/pages/inspections_page.dart';
import 'package:milow/features/inspections/presentation/pages/inspection_form_page.dart';
import 'package:milow/features/inbox/presentation/pages/chat_detail_page.dart';
import 'package:milow/features/auth/presentation/pages/email_verified_page.dart';
import 'package:milow/features/auth/presentation/pages/reset_password_page.dart';
import 'package:milow/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:milow/core/presentation/pages/force_update_page.dart';
import 'package:milow/features/dashboard/presentation/pages/quick_notes_page.dart';
import 'package:milow/features/dashboard/presentation/pages/maintenance_reminders_page.dart';
import 'package:milow/features/dashboard/presentation/pages/incident_report_page.dart';

import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/services/version_check_service.dart';
import 'package:milow_core/milow_core.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
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
      path: '/quick-notes',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: QuickNotesPage()),
      ),
    ),
    GoRoute(
      path: '/maintenance-reminders',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: MaintenanceRemindersPage()),
      ),
    ),
    GoRoute(
      path: '/incident-report',
      pageBuilder: (context, state) => _buildTransitionPage(
        context,
        state,
        const AuthWrapper(child: IncidentReportPage()),
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
