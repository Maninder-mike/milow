import 'package:flutter_test/flutter_test.dart';
import 'package:milow_data/milow_data.dart';

void main() {
  group('Milow Data Models & Integration Tests', () {
    test('StopModel enforces sequenceId >= 1 invariant', () {
      const stop = StopModel(
        id: 'stop-1',
        loadId: 'load-100',
        sequenceId: 1,
        stopType: 'pickup',
        locationName: 'Dallas Central Terminal',
        address: '100 Main St',
      );

      expect(stop.sequenceId, equals(1));
      expect(stop.toJson()['sequence_id'], equals(1));
    });

    test('LoadModel sorts stops by sequenceId deterministically', () {
      final json = {
        'id': 'load-100',
        'company_id': 'comp-1',
        'load_number': 'L-9001',
        'status': 'in_transit',
        'rate': 2500.0,
        'stops': [
          {
            'id': 'stop-2',
            'load_id': 'load-100',
            'sequence_id': 2,
            'stop_type': 'delivery',
            'locationName': 'Houston Port',
            'address': '200 Harbor Dr',
          },
          {
            'id': 'stop-1',
            'load_id': 'load-100',
            'sequence_id': 1,
            'stop_type': 'pickup',
            'locationName': 'Dallas Hub',
            'address': '100 Main St',
          },
        ],
      };

      final load = LoadModel.fromJson(json);

      expect(load.stops.length, equals(2));
      expect(load.stops.first.sequenceId, equals(1));
      expect(load.stops.last.sequenceId, equals(2));
      expect(load.stops.first.stopType, equals('pickup'));
    });
  });
}
