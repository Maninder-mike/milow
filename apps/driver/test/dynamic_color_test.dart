import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setMockDynamicColors({List<int>? corePalette, Color? accentColor}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('io.material.plugins/dynamic_color'),
      (MethodCall call) async {
        if (call.method == 'getCorePalette') {
          return corePalette != null ? Int64List.fromList(corePalette) : null;
        }
        if (call.method == 'getAccentColor') {
          return accentColor?.toARGB32();
        }
        return null;
      },
    );
  }

  group('Dynamic Color Tests', () {
    setUp(() {
      setMockDynamicColors();
    });

    tearDown(() {
      setMockDynamicColors();
    });

    testWidgets('Uses fallback theme when no dynamic colors available', (
      WidgetTester tester,
    ) async {
      setMockDynamicColors();

      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
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

    testWidgets('Uses dynamic colors when available from system accent', (
      WidgetTester tester,
    ) async {
      setMockDynamicColors(
        accentColor: const Color(0xFF4CAF50),
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

      expect(capturedLightScheme, isNotNull);
      expect(capturedDarkScheme, isNotNull);
      expect(capturedLightScheme!.primary, isNotNull);
    });

    testWidgets('Theme adapts to different accent color palette', (
      WidgetTester tester,
    ) async {
      setMockDynamicColors(
        accentColor: const Color(0xFF2196F3),
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
      expect(capturedScheme!.primary, isNotNull);
    });
  });
}
