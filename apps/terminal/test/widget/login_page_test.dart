import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/providers/supabase_provider.dart';
import 'package:terminal/features/auth/presentation/pages/login_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:terminal/core/providers/biometric_provider.dart';

import '../helpers/mocks.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockBiometricService mockBiometricService;
  late MockUser mockUser;
  late MockSession mockSession;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockBiometricService = MockBiometricService();
    mockUser = MockUser();
    mockSession = MockSession();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);

    // Stub BiometricService methods to return safe defaults
    when(
      mockBiometricService.isBiometricAvailable,
    ).thenAnswer((_) async => false);
    when(
      mockBiometricService.hasStoredCredentials(),
    ).thenAnswer((_) async => false);
    when(mockBiometricService.hasPin()).thenAnswer((_) async => false);

    // Stub saveCredentials to do nothing (void future)
    when(
      mockBiometricService.saveCredentials(any, any),
    ).thenAnswer((_) async {});
  });

  /// Creates a router with LoginPage as the initial route and a dashboard stub.
  GoRouter _createTestRouter() {
    return GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const fluent.ScaffoldPage(
            content: fluent.Center(child: fluent.Text('Dashboard')),
          ),
        ),
      ],
    );
  }

  testWidgets('LoginPage shows email and password fields and login button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          biometricServiceProvider.overrideWithValue(mockBiometricService),
        ],
        child: fluent.FluentApp.router(routerConfig: _createTestRouter()),
      ),
    );

    expect(find.text('Milow Terminal'), findsOneWidget);
    expect(
      find.byType(fluent.TextBox),
      findsNWidgets(2),
    ); // Email and Password inputs
    expect(find.text('Login with Password'), findsOneWidget);
  });

  testWidgets('Inputting credentials and clicking login calls Supabase Auth', (
    tester,
  ) async {
    // Arrange
    when(
      mockGoTrueClient.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenAnswer(
      (_) async => AuthResponse(session: mockSession, user: mockUser),
    );

    // Stub hasPin which is called after login
    when(mockBiometricService.hasPin()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          biometricServiceProvider.overrideWithValue(mockBiometricService),
        ],
        child: fluent.FluentApp.router(routerConfig: _createTestRouter()),
      ),
    );

    // Act
    await tester.enterText(
      find.widgetWithText(fluent.TextBox, 'Email'),
      'test@example.com',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(fluent.TextBox, 'Password'),
      'password123',
    );
    await tester.pump();

    await tester.tap(find.text('Login with Password'));

    // Wait for async operations and animations
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Assert
    verify(
      mockGoTrueClient.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      ),
    ).called(1);

    verify(
      mockBiometricService.saveCredentials('test@example.com', 'password123'),
    ).called(1);
  });
}
