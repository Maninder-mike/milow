import 'package:milow_data/milow_data.dart';

/// Pure Dart $0-cost IFTA fuel tax calculator and CSV audit exporter service.
class IftaCalculatorService {
  const IftaCalculatorService();

  /// Computes quarterly IFTA report from jurisdiction entries.
  IftaQuarterlyReport calculateQuarterlyReport({
    required String quarter,
    required String vehicleId,
    required List<IftaJurisdictionReport> jurisdictionEntries,
  }) {
    double totalMiles = 0.0;
    double totalGallons = 0.0;

    for (final entry in jurisdictionEntries) {
      totalMiles += entry.totalMiles;
      totalGallons += entry.taxPaidGallons;
    }

    return IftaQuarterlyReport(
      quarter: quarter,
      vehicleId: vehicleId,
      jurisdictions: jurisdictionEntries,
      totalFleetMiles: totalMiles,
      totalFleetGallons: totalGallons,
    );
  }

  /// Converts an IFTA quarterly report to a standard CSV string for tax filings.
  String exportToCsv(IftaQuarterlyReport report) {
    final buffer = StringBuffer();
    buffer.writeln('IFTA Quarterly Tax Filing Report');
    buffer.writeln('Quarter,${report.quarter}');
    buffer.writeln('Vehicle ID,${report.vehicleId}');
    buffer.writeln('Total Fleet Miles,${report.totalFleetMiles.toStringAsFixed(1)}');
    buffer.writeln('Total Fleet Gallons,${report.totalFleetGallons.toStringAsFixed(1)}');
    buffer.writeln('Fleet Average MPG,${report.averageMpg.toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Jurisdiction,Total Miles,Taxable Miles,Tax-Paid Gallons');

    for (final j in report.jurisdictions) {
      buffer.writeln(
        '${j.jurisdictionCode},${j.totalMiles.toStringAsFixed(1)},${j.taxableMiles.toStringAsFixed(1)},${j.taxPaidGallons.toStringAsFixed(1)}',
      );
    }

    return buffer.toString();
  }
}
