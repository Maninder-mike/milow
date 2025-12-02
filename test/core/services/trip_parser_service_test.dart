import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/services/trip_parser_service.dart';

void main() {
  group('TripParserService', () {
    test('parses valid trip text correctly', () {
      const text = '''
Trip# 11512
Truck# 117 Trailer# HPR302

Pick #1
CALDIC CANADA
1870 ST-REGIS BOULEVARD
DORVAL QC H9P1H6
Date 11/12/2025 Time 8AM--2PM
Notes PO#: 000604-5; Reference#: SO205583

Drop #1
ISLAND ABBEY FOOD
20 INNOVATION WAY
CHARLOTTETOWN PE C1E 0K4
Date 11/13/2025 Time 7AM-2PM
Notes PO#: 000604-5; Reference#: SO205583
''';

      final result = TripParserService.parse(text);

      expect(result['tripNumber'], '11512');
      expect(result['startLocation'], contains('CALDIC CANADA'));
      expect(result['startLocation'], contains('1870 ST-REGIS BOULEVARD'));
      expect(result['startLocation'], contains('DORVAL QC H9P1H6'));
      expect(result['endLocation'], contains('ISLAND ABBEY FOOD'));
      expect(result['endLocation'], contains('20 INNOVATION WAY'));
      expect(result['endLocation'], contains('CHARLOTTETOWN PE C1E 0K4'));
      expect(result['date'], '11/12/2025 8:00 AM');
      printOnFailure('Extracted date: ${result['date']}');
      expect(result['notes'], contains('PO#: 000604-5'));
    });

    test('returns empty map for empty text', () {
      final result = TripParserService.parse('');
      expect(result, isEmpty);
    });

    test('parses partial text correctly', () {
      const text = '''
Trip# 12345
Pick #1
Some Place
Date 10/10/2025 Time 10AM
''';
      final result = TripParserService.parse(text);
      expect(result['tripNumber'], '12345');
      expect(result['startLocation'], contains('Some Place'));
      expect(result['date'], '10/10/2025 10:00 AM');
    });
  });
}
