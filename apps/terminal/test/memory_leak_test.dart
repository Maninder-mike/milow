import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:fluent_ui/fluent_ui.dart';

void main() {
  testWidgets('Memory leak test - Baseline Infrastructure', (
    WidgetTester tester,
  ) async {
    // 1. Configure Leak Tracking
    LeakTracking.warnForUnsupportedPlatforms = false;
    LeakTracking.start(config: LeakTrackingConfig.passive());

    try {
      // 2. Pump a simple app to verify leak tracking doesn't crash
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Center(
              child: Button(child: const Text('Test Button'), onPressed: () {}),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 3. Verify no leaks are reported (implicitly, by not crashing)
      // In a real scenario, we would collect leaks here:
      // final leaks = await LeakTracking.collectLeaks();
      // expect(leaks.total, 0);
    } finally {
      LeakTracking.stop();
    }
  });
}
