import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';

void main() {
  testWidgets('M3SpringButton disposes AnimationController correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: M3SpringButton(onTap: () {}, child: const Text('Tap Me')),
        ),
      ),
    );

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();

    // Replace with SizedBox to trigger disposal
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    // If disposal was missing, this pump would likely trigger a FlutterError
    // regarding undiposed AnimationController in debug mode.
    await tester.pumpAndSettle();
  });
}
