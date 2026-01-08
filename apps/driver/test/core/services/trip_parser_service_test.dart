import 'package:flutter_test/flutter_test.dart';
import 'package:milow/core/services/trip_parser_service.dart';

void main() {
  group('TripParserService', () {
    test('parses standard trip text correctly', () {
      const text = '''
Trip# 11759
Truck# 117
Trailer# 5301

Pick #1
3305 DORCHESTER RD
Date 01/08/2026 Time 12:00 PM

Drop #1
123 Delivery Lane
Date 01/08/2026 Time 05:00 PM

Notes Handle with care
''';

      final result = TripParserService.parse(text);

      expect(result['tripNumber'], '11759');
      expect(result['truckNumber'], '117');
      expect(result['trailerNumber'], '5301');
      expect(result['startLocation'], '3305 DORCHESTER RD');
      expect(result['endLocation'], '123 Delivery Lane');
      expect(result['notes'], 'Handle with care');
    });

    test('parses trailer number with different formats', () {
      // Case 1: Space before #
      var text = 'Trailer # 5301';
      var result = TripParserService.parse(text);
      expect(
        result['trailerNumber'],
        '5301',
        reason: 'Failed to parse "Trailer # 5301"',
      );

      // Case 2: Colon instead of #
      text = 'Trailer: 5301';
      result = TripParserService.parse(text);
      expect(
        result['trailerNumber'],
        '5301',
        reason: 'Failed to parse "Trailer: 5301"',
      );

      // Case 3: No space
      text = 'Trailer#5301';
      result = TripParserService.parse(text);
      expect(
        result['trailerNumber'],
        '5301',
        reason: 'Failed to parse "Trailer#5301"',
      );
    });

    test('parses delivery location correctly', () {
      const text = '''
Drop #1
Warehouse B, Dock 4
Date 01/09/2026 Time 08:00 AM
''';
      final result = TripParserService.parse(text);
      expect(result['endLocation'], 'Warehouse B, Dock 4');
    });

    test('parses delivery location with multiline address', () {
      const text = '''
Drop #1
123 Main St
Suite 100
Date 01/09/2026 Time 08:00 AM
''';
      final result = TripParserService.parse(text);
      expect(result['endLocation'], '123 Main St, Suite 100');
    });
  });
}
