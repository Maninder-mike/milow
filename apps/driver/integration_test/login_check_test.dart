import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:milow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow Integration Test', () {
    testWidgets('App starts and shows login page', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Verify we are on the Login Page (or Splash then Login)
      // Assuming fresh install state or logged out state
      // We might need to hunt for widgets.

      // Look for Email field
      final emailField = find
          .byType(TextFormField)
          .at(0); // Assuming email is first
      // or find by specific key if added

      // If we are logged in, we might see Home.
      // For a test environment, we ideally want a clean slate.

      // Verify emailField is found and form structure is present
      expect(emailField, findsOneWidget);
      expect(find.text('Login'), findsOneWidget); // Assuming header text
    });
  });
}
