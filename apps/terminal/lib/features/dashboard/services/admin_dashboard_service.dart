import 'package:fl_chart/fl_chart.dart';

class AdminDashboardService {
  // Mock Data for KPI Cards
  Future<Map<String, dynamic>> getKPIData() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    return {
      'operatingRatio': 82.5, // Target < 85%
      'maintenanceCompliance': 0.94, // 94%
      'driverRetention': 92.0, // 92%
      'accountsReceivable': {
        'total': 125430.00,
        '30days': 85000.00,
        '60days': 25000.00,
        '90days': 15430.00,
      },
    };
  }

  // Mock Data for Cost Per Mile (Line Chart)
  Future<List<FlSpot>> getCPMData() async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Last 6 months trend
    return const [
      FlSpot(0, 1.85), // Month 1
      FlSpot(1, 1.92),
      FlSpot(2, 1.78),
      FlSpot(3, 1.88),
      FlSpot(4, 2.05),
      FlSpot(5, 1.95), // Current Month
    ];
  }

  // Mock Data for Top Trucks (Bar Chart)
  Future<List<Map<String, dynamic>>> getTopTrucksData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      {'truck': 'Unit 101', 'revenue': 25000.0},
      {'truck': 'Unit 305', 'revenue': 22400.0},
      {'truck': 'Unit 202', 'revenue': 21000.0},
      {'truck': 'Unit 108', 'revenue': 19500.0},
      {'truck': 'Unit 404', 'revenue': 18200.0},
      {'truck': 'Unit 115', 'revenue': 17500.0},
      {'truck': 'Unit 310', 'revenue': 16800.0},
      {'truck': 'Unit 222', 'revenue': 15000.0},
      {'truck': 'Unit 401', 'revenue': 14200.0},
      {'truck': 'Unit 105', 'revenue': 13000.0},
    ];
  }
}
