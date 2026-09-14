import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow_ui/milow_ui.dart';

void main() {
  group('EmptyStateWidget Tests', () {
    testWidgets('renders title, subtitle, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.local_shipping_outlined,
              title: 'No Loads Found',
              subtitle: 'Create your first load to get started.',
            ),
          ),
        ),
      );

      expect(find.text('No Loads Found'), findsOneWidget);
      expect(find.text('Create your first load to get started.'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders primary CTA button when provided and triggers callback',
        (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.person_add_outlined,
              title: 'No Drivers Listed',
              subtitle: 'Invite drivers to assign loads.',
              primaryActionLabel: 'Add Driver',
              onPrimaryAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Driver'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(actionTriggered, isTrue);
    });
  });
}
