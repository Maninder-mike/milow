import 'package:flutter_test/flutter_test.dart';
import 'package:milow_data/milow_data.dart';
import 'package:terminal/features/dispatch/presentation/utils/ratecon_generator.dart';

void main() {
  group('RateConGenerator Unit Tests', () {
    test('generatePdf builds non-empty PDF byte buffer for valid LoadModel', () async {
      final load = LoadModel(
        id: 'load-505',
        companyId: 'company-1',
        loadNumber: 'RC-9988',
        status: 'assigned',
        rate: 1850.00,
        stops: const [
          StopModel(
            id: 'stop-1',
            loadId: 'load-505',
            sequenceId: 1,
            stopType: 'pickup',
            locationName: 'Dallas Warehouse A',
            address: '100 Industrial Pkwy',
            city: 'Dallas',
            state: 'TX',
          ),
          StopModel(
            id: 'stop-2',
            loadId: 'load-505',
            sequenceId: 2,
            stopType: 'delivery',
            locationName: 'Memphis Logistics Hub',
            address: '500 Cargo Rd',
            city: 'Memphis',
            state: 'TN',
          ),
        ],
      );

      final pdfBytes = await RateConGenerator.generatePdf(
        load: load,
        brokerName: 'Milow Logistics Inc',
        carrierName: 'Swift Transports',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
