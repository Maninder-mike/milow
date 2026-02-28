class SettlementSummary {
  final double totalPending;
  final double totalPaid;
  final double averagePayout;
  final int unsettledItemsCount;

  SettlementSummary({
    required this.totalPending,
    required this.totalPaid,
    required this.averagePayout,
    required this.unsettledItemsCount,
  });

  factory SettlementSummary.empty() {
    return SettlementSummary(
      totalPending: 0,
      totalPaid: 0,
      averagePayout: 0,
      unsettledItemsCount: 0,
    );
  }
}
