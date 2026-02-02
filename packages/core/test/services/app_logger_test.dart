import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milow_core/src/services/app_logger.dart';

void main() {
  final List<String> logLines = [];

  void mockDebugPrint(String? message, {int? wrapWidth}) {
    if (message != null) logLines.add(message);
  }

  group('AppLogger Debug Mode', () {
    setUp(() {
      logLines.clear();
      debugPrint = mockDebugPrint;
      // Tests run in debug mode by default in Flutter.
    });

    tearDown(() {
      debugPrint = (String? message, {int? wrapWidth}) {}; // Reset
    });

    test('debug logs to console', () {
      AppLogger.debug('test debug message');
      expect(
        logLines.any((line) => line.contains('[DEBUG] test debug message')),
        true,
      );
    });

    test('info logs to console', () {
      AppLogger.info('test info message');
      expect(
        logLines.any((line) => line.contains('[INFO] test info message')),
        true,
      );
    });

    test('warning logs with context', () {
      AppLogger.warning('test warning', context: {'key': 'value'});
      expect(
        logLines.any((line) => line.contains('[WARNING] test warning')),
        true,
      );
      expect(
        logLines.any((line) => line.contains('Context: {key: value}')),
        true,
      );
    });

    test('error logs with exception', () {
      final exception = Exception('bang');
      AppLogger.error('test error', error: exception);
      expect(logLines.any((line) => line.contains('[ERROR] test error')), true);
      expect(
        logLines.any((line) => line.contains('Error: Exception: bang')),
        true,
      );
    });
  });

  // Release mode tests would require kDebugMode to be false, which is hard to simulate in unit tests
  // without using a separate entry point or compilation mode.
}
