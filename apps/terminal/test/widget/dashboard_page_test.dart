import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/features/dashboard/screens/overview_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences for Supabase auth persistence
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with fake credentials to pass the assertion
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'fake-anon-key',
      );
    } catch (_) {
      // Already initialized
    }
  });

  testWidgets('OverviewPage loads and shows placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: fluent.FluentApp(home: OverviewPage())),
    );

    // Verify Welcome message is GONE
    expect(find.text('Welcome to Milow Terminal'), findsNothing);

    // Verify Placeholder is PRESENT
    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
  });
}
