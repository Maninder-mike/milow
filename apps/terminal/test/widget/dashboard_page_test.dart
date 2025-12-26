import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/features/dashboard/screens/overview_page.dart';

void main() {
  testWidgets('OverviewPage loads and shows welcome message', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: fluent.FluentApp(home: OverviewPage())),
    );

    // Verify title
    expect(find.text('Welcome to Milow Terminal'), findsOneWidget);
    expect(
      find.text('Select a module from the sidebar to get started.'),
      findsOneWidget,
    );
  });
}
