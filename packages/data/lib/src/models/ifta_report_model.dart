/// IFTA Quarterly Tax Report model for a specific jurisdiction (State / Province).
class IftaJurisdictionReport {
  const IftaJurisdictionReport({
    required this.jurisdictionCode, // e.g. 'TX', 'CA', 'IL', 'ON'
    required this.totalMiles,
    required this.taxableMiles,
    required this.taxPaidGallons,
  });

  factory IftaJurisdictionReport.fromJson(Map<String, dynamic> json) {
    return IftaJurisdictionReport(
      jurisdictionCode: json['jurisdiction_code'] as String? ?? '',
      totalMiles: (json['total_miles'] as num?)?.toDouble() ?? 0.0,
      taxableMiles: (json['taxable_miles'] as num?)?.toDouble() ?? 0.0,
      taxPaidGallons: (json['tax_paid_gallons'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String jurisdictionCode;
  final double totalMiles;
  final double taxableMiles;
  final double taxPaidGallons;

  Map<String, dynamic> toJson() {
    return {
      'jurisdiction_code': jurisdictionCode,
      'total_miles': totalMiles,
      'taxable_miles': taxableMiles,
      'tax_paid_gallons': taxPaidGallons,
    };
  }
}

/// Overall quarterly IFTA audit summary report.
class IftaQuarterlyReport {
  const IftaQuarterlyReport({
    required this.quarter, // e.g. 'Q1 2026'
    required this.vehicleId,
    required this.jurisdictions,
    required this.totalFleetMiles,
    required this.totalFleetGallons,
  });

  final String quarter;
  final String vehicleId;
  final List<IftaJurisdictionReport> jurisdictions;
  final double totalFleetMiles;
  final double totalFleetGallons;

  double get averageMpg =>
      totalFleetGallons > 0 ? totalFleetMiles / totalFleetGallons : 0.0;
}
