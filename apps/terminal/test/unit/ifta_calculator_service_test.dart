import 'package:flutter_test/flutter_test.dart';
import 'package:milow_data/milow_data.dart';
import 'package:terminal/features/analytics/services/ifta_calculator_service.dart';

void main() {
  group('IftaCalculatorService Tests', () {
    const service = IftaCalculatorService();

    test('calculateQuarterlyReport aggregates total miles and gallons correctly', () {
      final report = service.calculateQuarterlyReport(
        quarter: 'Q1 2026',
        vehicleId: 'TRUCK-101',
        jurisdictionEntries: const [
          IftaJurisdictionReport(
            jurisdictionCode: 'TX',
            totalMiles: 1200.0,
            taxableMiles: 1200.0,
            taxPaidGallons: 200.0,
          ),
          IftaJurisdictionReport(
            jurisdictionCode: 'OK',
            totalMiles: 600.0,
            taxableMiles: 600.0,
            taxPaidGallons: 100.0,
          ),
        ],
      );

      expect(report.totalFleetMiles, equals(1800.0));
      expect(report.totalFleetGallons, equals(300.0));
      expect(report.averageMpg, equals(6.0));
    });

    test('exportToCsv formats quarterly report correctly', () {
      final report = service.calculateQuarterlyReport(
        quarter: 'Q1 2026',
        vehicleId: 'TRUCK-101',
        jurisdictionEntries: const [
          IftaJurisdictionReport(
            jurisdictionCode: 'TX',
            totalMiles: 1000.0,
            taxableMiles: 1000.0,
            taxPaidGallons: 150.0,
          ),
        ],
      );

      final csv = service.exportToCsv(report);

      expect(csv, contains('IFTA Quarterly Tax Filing Report'));
      expect(csv, contains('TX,1000.0,1000.0,150.0'));
    });
  });
}
