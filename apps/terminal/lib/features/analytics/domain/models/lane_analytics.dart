class LaneAnalytics {
  final String originCity;
  final String originState;
  final String destinationCity;
  final String destinationState;
  final int loadCount;
  final double totalRevenue;
  final double averageRate;

  const LaneAnalytics({
    required this.originCity,
    required this.originState,
    required this.destinationCity,
    required this.destinationState,
    required this.loadCount,
    required this.totalRevenue,
    required this.averageRate,
  });

  String get origin => '$originCity, $originState';
  String get destination => '$destinationCity, $destinationState';
  String get lane => '$origin -> $destination';
}
