class RevenueDataPoint {
  final DateTime date;
  final double amount;
  final int loadCount;

  const RevenueDataPoint({
    required this.date,
    required this.amount,
    required this.loadCount,
  });

  factory RevenueDataPoint.fromJson(Map<String, dynamic> json) {
    return RevenueDataPoint(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      loadCount: (json['load_count'] as num).toInt(),
    );
  }
}
