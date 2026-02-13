class DriverPerformance {
  final String driverId;
  final String driverName;
  final int completedLoads;
  final double totalRevenue;
  final double totalMiles;

  const DriverPerformance({
    required this.driverId,
    required this.driverName,
    required this.completedLoads,
    required this.totalRevenue,
    required this.totalMiles,
  });

  double get revenuePerMile => totalMiles > 0 ? totalRevenue / totalMiles : 0.0;

  double get averageRevenuePerLoad =>
      completedLoads > 0 ? totalRevenue / completedLoads : 0.0;
}
