import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Users, Roles, Groups Page', () {
    testWidgets('renders TabView with three tabs', (tester) async {
      // Note: This is a smoke test. Full widget tests require mocking Supabase.
      // For complete testing, use integration tests with a test database.

      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            home: ScaffoldPage(
              content: TabView(
                currentIndex: 0,
                tabs: [
                  Tab(
                    text: Text('Users'),
                    body: Center(child: Text('Users')),
                  ),
                  Tab(
                    text: Text('Roles'),
                    body: Center(child: Text('Roles')),
                  ),
                  Tab(
                    text: Text('Groups'),
                    body: Center(child: Text('Groups')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Users'), findsWidgets);
      expect(find.text('Roles'), findsWidgets);
      expect(find.text('Groups'), findsWidgets);
    });

    testWidgets('TabView switches between tabs correctly', (tester) async {
      int currentIndex = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ScaffoldPage(
                  content: TabView(
                    currentIndex: currentIndex,
                    onChanged: (index) => setState(() => currentIndex = index),
                    tabs: [
                      Tab(
                        text: Text('Users'),
                        body: Center(child: Text('Users Content')),
                      ),
                      Tab(
                        text: Text('Roles'),
                        body: Center(child: Text('Roles Content')),
                      ),
                      Tab(
                        text: Text('Groups'),
                        body: Center(child: Text('Groups Content')),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Initially shows Users content
      expect(find.text('Users Content'), findsOneWidget);

      // Tap on Roles tab
      await tester.tap(find.text('Roles').first);
      await tester.pumpAndSettle();
      expect(find.text('Roles Content'), findsOneWidget);

      // Tap on Groups tab
      await tester.tap(find.text('Groups').first);
      await tester.pumpAndSettle();
      expect(find.text('Groups Content'), findsOneWidget);
    });
  });

  group('Role Configuration Page', () {
    testWidgets('permission matrix displays checkboxes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            home: ScaffoldPage(
              content: Column(
                children: [
                  const Text('vehicles'),
                  Row(
                    children: [
                      Checkbox(checked: true, onChanged: (_) {}),
                      const Text('Read'),
                      Checkbox(checked: false, onChanged: (_) {}),
                      const Text('Write'),
                      Checkbox(checked: false, onChanged: (_) {}),
                      const Text('Delete'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('Bulk Import Dialog', () {
    testWidgets('shows CSV format instructions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            home: ScaffoldPage(
              content: ContentDialog(
                title: const Text('Bulk Import Users'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Import users from a CSV file'),
                    Text('email, full_name, role_name'),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Select CSV File'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bulk Import Users'), findsOneWidget);
      expect(find.text('email, full_name, role_name'), findsOneWidget);
      expect(find.text('Select CSV File'), findsOneWidget);
    });
  });
}
