import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal/main.dart';
import 'package:terminal/core/providers/supabase_provider.dart';
import 'package:terminal/core/providers/biometric_provider.dart';
import 'package:terminal/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test/helpers/mocks.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrue;
  late MockBiometricService mockBiometricService;
  late SharedPreferences sharedPrefs;
  late StreamController<AuthState> authStateController;

  setUp(() async {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockBiometricService = MockBiometricService();
    authStateController = StreamController<AuthState>.broadcast();

    // Setup Supabase mocks
    when(mockSupabaseClient.auth).thenReturn(mockGoTrue);
    when(
      mockGoTrue.onAuthStateChange,
    ).thenAnswer((_) => authStateController.stream);
    when(mockGoTrue.currentSession).thenReturn(null);

    // Setup Biometric mocks
    when(
      mockBiometricService.isBiometricAvailable,
    ).thenAnswer((_) async => false);
    when(mockBiometricService.hasPin()).thenAnswer((_) async => false);
    when(
      mockBiometricService.hasStoredCredentials(),
    ).thenAnswer((_) async => false);

    // Setup SharedPreferences
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    authStateController.close();
  });

  testWidgets('Auth Flow: Login with password success', (tester) async {
    // Arrange
    when(
      mockGoTrue.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ),
    ).thenAnswer(
      (_) async => AuthResponse(
        session: Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: User(
            id: 'id',
            appMetadata: {},
            userMetadata: {},
            aud: '',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),
        user: null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabaseClient),
          biometricServiceProvider.overrideWithValue(mockBiometricService),
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ],
        child: const AdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Assert Initial State
    expect(find.text('Milow Terminal'), findsOneWidget);
    expect(find.text('Login with Password'), findsOneWidget);

    // Act: Enter Credentials
    // Fluent UI TextBox might use slightly different structure, ensuring we find it.
    // Using find.byType(TextBox) and entering text.

    final emailFinder = find.widgetWithText(TextBox, 'Email');
    final passwordFinder = find.widgetWithText(TextBox, 'Password');

    // Note: widgetWithText searches specifically for a widget of type T which has a descendant Text with 'text'.
    // If TextBox placeholder is NOT a Text widget descendant but painted, this fails.
    // Fallback: Find by type and index if needed.
    // Let's assume widgetWithText works for now or fallback to iterating TextBoxes.

    try {
      await tester.enterText(emailFinder, 'test@example.com');
    } catch (e) {
      // Fallback strategy
      await tester.enterText(find.byType(TextBox).at(0), 'test@example.com');
    }

    try {
      await tester.enterText(passwordFinder, 'password123');
    } catch (e) {
      await tester.enterText(find.byType(TextBox).at(1), 'password123');
    }

    await tester.tap(find.text('Login with Password'));
    await tester.pump(); // Start animation/async work

    // Assert
    verify(
      mockGoTrue.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      ),
    ).called(1);
  });
}
