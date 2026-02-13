import 'package:milow_core/milow_core.dart';
import 'package:collection/collection.dart';
import '../../domain/models/analytics_timeframe.dart';
import '../../domain/models/revenue_data_point.dart';
import '../../domain/models/driver_performance.dart';
import '../../domain/models/lane_analytics.dart';

class AnalyticsRepository {
  final CoreNetworkClient _client;

  AnalyticsRepository(this._client);

  /// Fetch revenue trend data grouped by day/week/month based on timeframe.
  Future<Result<List<RevenueDataPoint>>> fetchRevenueTrend(
    AnalyticsTimeframe timeframe,
  ) async {
    return _client.query<List<RevenueDataPoint>>(() async {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: timeframe.days));
      final startDateStr = startDate.toIso8601String();

      // Fetch invoices within range
      final response = await _client.supabase
          .from('invoices')
          .select('created_at, total_amount')
          .gte('created_at', startDateStr)
          .order('created_at');

      final data = response as List<dynamic>;

      // Aggregate by date (day)
      // For longer timeframes (year), we might want to aggregate by month visually,
      // but providing daily data gives flexibility to the chart.
      final Map<String, _RevenueAggregator> dailyMap = {};

      for (var item in data) {
        final dateStr = (item['created_at'] as String).split(
          'T',
        )[0]; // YYYY-MM-DD
        final amount = (item['total_amount'] as num).toDouble();

        if (!dailyMap.containsKey(dateStr)) {
          dailyMap[dateStr] = _RevenueAggregator();
        }
        dailyMap[dateStr]!.add(amount);
      }

      // Convert to list and sort
      final List<RevenueDataPoint> points = dailyMap.entries.map((e) {
        return RevenueDataPoint(
          date: DateTime.parse(e.key),
          amount: e.value.totalAmount,
          loadCount: e.value.count,
        );
      }).toList();

      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    }, operationName: 'fetchRevenueTrend');
  }

  /// Fetch load volume trend (count of loads created/completed) by date.
  /// Currently using 'created_at' as the metric for volume.
  Future<Result<List<RevenueDataPoint>>> fetchLoadVolume(
    AnalyticsTimeframe timeframe,
  ) async {
    return _client.query<List<RevenueDataPoint>>(() async {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: timeframe.days));
      final startDateStr = startDate.toIso8601String();

      final response = await _client.supabase
          .from('loads')
          .select('created_at, rate')
          .gte('created_at', startDateStr)
          .order('created_at');

      final data = response as List<dynamic>;
      final Map<String, _RevenueAggregator> dailyMap = {};

      for (var item in data) {
        final dateStr = (item['created_at'] as String).split('T')[0];
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;

        if (!dailyMap.containsKey(dateStr)) {
          dailyMap[dateStr] = _RevenueAggregator();
        }
        dailyMap[dateStr]!.add(rate);
      }

      final List<RevenueDataPoint> points = dailyMap.entries.map((e) {
        return RevenueDataPoint(
          date: DateTime.parse(e.key),
          amount: e
              .value
              .totalAmount, // Using amount field for Rate here if needed, or just ignore
          loadCount: e.value.count,
        );
      }).toList();

      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    }, operationName: 'fetchLoadVolume');
  }

  /// Fetch performance stats per driver.
  Future<Result<List<DriverPerformance>>> fetchDriverPerformance(
    AnalyticsTimeframe timeframe,
  ) async {
    return _client.query<List<DriverPerformance>>(() async {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: timeframe.days));
      final startDateStr = startDate.toIso8601String();

      // We need loads joined with drivers (users or profiles? usually profiles or a driver table)
      // Since 'assigned_driver_id' is on loads, let's fetch loads and aggregate manually.
      // Note: This relies on assigned_driver_id being populated.

      final response = await _client.supabase
          .from('loads')
          .select('''
            assigned_driver_id,
            rate,
            stops(city, state_province, stop_type)
          ''')
          .gte('created_at', startDateStr)
          .not('assigned_driver_id', 'is', null);

      final data = response as List<dynamic>;
      final Map<String, _DriverStats> driverMap = {};

      for (var item in data) {
        final driverId = item['assigned_driver_id'] as String;
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;

        // Approximate miles calculation would typically come from the load data directly
        // if we stored 'total_miles'. If not, we can't calculate it here easily without
        // external GIS. For now, we'll placeholder 0 miles or try to find a field.
        // Looking at load_repository, 'total_miles' isn't explicitly selected usually.
        // Let's assume 0 for now unless we find it in schema.

        if (!driverMap.containsKey(driverId)) {
          driverMap[driverId] = _DriverStats();
        }
        driverMap[driverId]!.addLoad(rate, 0);
      }

      // Helper to fetch driver names
      // We can do a second query for profiles where id in keys
      if (driverMap.isEmpty) return [];

      final driverIds = driverMap.keys.toList();
      final profilesRes = await _client.supabase
          .from('profiles')
          .select('id, first_name, last_name')
          .filter('id', 'in', driverIds);

      final profiles = profilesRes as List<dynamic>;
      final nameMap = {
        for (var p in profiles)
          p['id'] as String: '${p['first_name']} ${p['last_name']}',
      };

      return driverMap.entries.map((e) {
        return DriverPerformance(
          driverId: e.key,
          driverName: nameMap[e.key] ?? 'Unknown Driver',
          completedLoads: e.value.loadCount,
          totalRevenue: e.value.totalRevenue,
          totalMiles: e.value.totalMiles,
        );
      }).toList();
    }, operationName: 'fetchDriverPerformance');
  }

  /// Fetch top lanes analytics.
  Future<Result<List<LaneAnalytics>>> fetchLaneAnalytics(
    AnalyticsTimeframe timeframe,
  ) async {
    return _client.query<List<LaneAnalytics>>(() async {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: timeframe.days));
      final startDateStr = startDate.toIso8601String();

      // Complex join: Loads -> Stops (Pickup) AND Loads -> Stops (Delivery)
      // To simplify, we can fetch loads with all stops and parse logic in Dart.

      final response = await _client.supabase
          .from('loads')
          .select('''
            rate,
            stops(city, state_province, stop_type, sequence_id)
          ''')
          .gte('created_at', startDateStr);

      final data = response as List<dynamic>;
      final Map<String, _LaneStats> laneMap = {};

      for (var item in data) {
        final stops = (item['stops'] as List<dynamic>?) ?? [];
        if (stops.isEmpty) continue;

        // Simple logic: First Pickup -> Last Delivery
        // Ideally sorting by sequence_id
        stops.sort(
          (a, b) => (a['sequence_id'] as int? ?? 0).compareTo(
            b['sequence_id'] as int? ?? 0,
          ),
        );

        final pickup = stops.firstWhereOrNull(
          (s) => s['stop_type'] == 'Pickup',
        );
        final delivery = stops.lastWhereOrNull(
          (s) => s['stop_type'] == 'Delivery',
        );

        if (pickup != null && delivery != null) {
          final originCity = pickup['city'] ?? '';
          final originState = pickup['state_province'] ?? '';
          final destCity = delivery['city'] ?? '';
          final destState = delivery['state_province'] ?? '';

          if (originCity.isEmpty || destCity.isEmpty) continue;

          final key = '$originCity,$originState|$destCity,$destState';
          final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;

          if (!laneMap.containsKey(key)) {
            laneMap[key] = _LaneStats(
              originCity: originCity,
              originState: originState,
              destinationCity: destCity,
              destinationState: destState,
            );
          }
          laneMap[key]!.addLoad(rate);
        }
      }

      final results = laneMap.values
          .map(
            (stats) => LaneAnalytics(
              originCity: stats.originCity,
              originState: stats.originState,
              destinationCity: stats.destinationCity,
              destinationState: stats.destinationState,
              loadCount: stats.loadCount,
              totalRevenue: stats.totalRevenue,
              averageRate: stats.averageRate,
            ),
          )
          .toList();

      // Sort by frequency
      results.sort((a, b) => b.loadCount.compareTo(a.loadCount));

      // Top 10
      return results.take(10).toList();
    }, operationName: 'fetchLaneAnalytics');
  }
}

// --- Helper aggregators ---

class _RevenueAggregator {
  double totalAmount = 0;
  int count = 0;

  void add(double amount) {
    totalAmount += amount;
    count++;
  }
}

class _DriverStats {
  int loadCount = 0;
  double totalRevenue = 0;
  double totalMiles = 0;

  void addLoad(double revenue, double miles) {
    loadCount++;
    totalRevenue += revenue;
    totalMiles += miles;
  }
}

class _LaneStats {
  final String originCity;
  final String originState;
  final String destinationCity;
  final String destinationState;

  int loadCount = 0;
  double totalRevenue = 0;

  _LaneStats({
    required this.originCity,
    required this.originState,
    required this.destinationCity,
    required this.destinationState,
  });

  void addLoad(double rate) {
    loadCount++;
    totalRevenue += rate;
  }

  double get averageRate => loadCount > 0 ? totalRevenue / loadCount : 0.0;
}
