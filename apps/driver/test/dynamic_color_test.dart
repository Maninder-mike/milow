import 'package:dynamic_color/dynamic_color.dart';
import 'package:dynamic_color/test_utils.dart';
import 'package:dynamic_color/samples.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/theme/app_theme.dart';

void main() {
  group('Dynamic Color Tests', () {
    setUp(() {
      // Reset mock dynamic colors before each test
      DynamicColorTestingUtils.setMockDynamicColors();
    });

    testWidgets('Uses fallback theme when no dynamic colors available', (
      WidgetTester tester,
    ) async {
      // No dynamic colors set - should use AppTheme defaults
      DynamicColorTestingUtils.setMockDynamicColors();

      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            // Verify no dynamic colors are provided
            expect(lightDynamic, isNull);
            expect(darkDynamic, isNull);

            return MaterialApp(
              theme: AppTheme.lightTheme.copyWith(
                colorScheme: lightDynamic ?? AppTheme.lightTheme.colorScheme,
              ),
              home: const Scaffold(body: Text('Test')),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('Uses dynamic colors when available from wallpaper', (
      WidgetTester tester,
    ) async {
      // Simulate Android 12+ with green wallpaper
      DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green,
      );

      ColorScheme? capturedLightScheme;
      ColorScheme? capturedDarkScheme;

      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            capturedLightScheme = lightDynamic;
            capturedDarkScheme = darkDynamic;

            return MaterialApp(
              theme: AppTheme.lightTheme.copyWith(
                colorScheme: lightDynamic ?? AppTheme.lightTheme.colorScheme,
              ),
              darkTheme: AppTheme.darkTheme.copyWith(
                colorScheme: darkDynamic ?? AppTheme.darkTheme.colorScheme,
              ),
              home: const Scaffold(body: Text('Test')),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Dynamic colors should be provided
      expect(capturedLightScheme, isNotNull);
      expect(capturedDarkScheme, isNotNull);
    });

    testWidgets('Theme adapts to different wallpaper palette', (
      WidgetTester tester,
    ) async {
      DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green,
      );

      ColorScheme? capturedScheme;

      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            capturedScheme = lightDynamic;

            return MaterialApp(
              theme: ThemeData(colorScheme: lightDynamic),
              home: const Scaffold(body: Text('Theme Test')),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScheme, isNotNull);
      // Verify the primary color was set from the palette
      expect(capturedScheme!.primary, isNotNull);
    });
  });
}
