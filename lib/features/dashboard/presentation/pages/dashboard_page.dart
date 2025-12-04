import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/widgets/app_scaffold.dart';
import 'package:milow/core/widgets/dashboard_card.dart';
import 'package:milow/core/widgets/section_header.dart';
import 'package:milow/core/widgets/news_card.dart';
import 'package:milow/core/widgets/border_wait_time_card.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
import 'package:milow/features/dashboard/presentation/pages/news_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/global_search_page.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final WeatherService _weatherService = WeatherService();
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  bool _showWeather = true; // User preference
  String _temperatureUnit = 'C'; // C or F
  String? _weatherError;

  // Border wait times
  List<BorderWaitTime> _borderWaitTimes = [];
  bool _isLoadingBorders = true;
  String? _borderError;
  Timer? _borderRefreshTimer;

  // Recent entries (trips and fuel)
  List<dynamic> _recentEntries = [];
  bool _isLoadingEntries = true;

  // Dashboard stats
  int _totalTrips = 0;
  double _totalMiles = 0;
  String _distanceUnit = 'mi';
  String _tripsTrend = '+0%';
  String _milesTrend = '+0%';
  String _timePeriod = 'weekly'; // weekly, biweekly, monthly, yearly

  // Realtime subscriptions
  RealtimeChannel? _tripsChannel;
  RealtimeChannel? _fuelChannel;

  // Notification state
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWeather();
    _loadBorderWaitTimes(
      forceRefresh: false,
    ); // Use prefetched data if available
    _loadRecentEntries();
    _loadDashboardStats();
    _setupRealtimeSubscriptions();
    _loadNotificationCount();
    // Refresh border wait times every 5 minutes
    _borderRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadBorderWaitTimes(forceRefresh: true),
    );
  }

  @override
  void dispose() {
    _borderRefreshTimer?.cancel();
    _tripsChannel?.unsubscribe();
    _fuelChannel?.unsubscribe();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    await NotificationService.instance.init();
    _unreadNotificationCount = NotificationService.instance.unreadCount;
    _notificationSubscription = NotificationService.instance.unreadCountStream
        .listen((count) {
          if (mounted) {
            setState(() {
              _unreadNotificationCount = count;
            });
          }
        });
    if (mounted) {
      setState(() {});
    }
  }

  void _setupRealtimeSubscriptions() {
    final supabase = Supabase.instance.client;

    // Subscribe to trips table changes
    _tripsChannel = supabase
        .channel('dashboard_trips')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            // Invalidate cache so next load fetches fresh data
            DataPrefetchService.instance.invalidateCache();
            _loadRecentEntries();
            _loadDashboardStats();
          },
        )
        .subscribe();

    // Subscribe to fuel_entries table changes
    _fuelChannel = supabase
        .channel('dashboard_fuel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fuel_entries',
          callback: (payload) {
            // Invalidate cache so next load fetches fresh data
            DataPrefetchService.instance.invalidateCache();
            _loadRecentEntries();
          },
        )
        .subscribe();
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Use prefetched data if available
      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      String distanceUnit;

      if (prefetch.isPrefetchComplete && prefetch.cachedTrips != null) {
        trips = prefetch.cachedTrips!;
        distanceUnit = prefetch.cachedDistanceUnit;
      } else {
        trips = await TripService.getTrips();
        distanceUnit = await PreferencesService.getDistanceUnit();
      }

      double totalMiles = 0;
      for (final trip in trips) {
        if (trip.totalDistance != null) {
          totalMiles += trip.totalDistance!;
        }
      }

      // Calculate trends based on time period
      final trends = _calculateTrends(trips);

      if (mounted) {
        setState(() {
          _totalTrips = trips.length;
          _totalMiles = totalMiles;
          _distanceUnit = distanceUnit;
          _tripsTrend = trends['tripsTrend']!;
          _milesTrend = trends['milesTrend']!;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Calculate trend percentages based on selected time period
  Map<String, String> _calculateTrends(List<Trip> allTrips) {
    final now = DateTime.now();
    DateTime compareDate;

    switch (_timePeriod) {
      case 'weekly':
        compareDate = now.subtract(const Duration(days: 7));
        break;
      case 'biweekly':
        compareDate = now.subtract(const Duration(days: 14));
        break;
      case 'monthly':
        compareDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'yearly':
        compareDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        compareDate = now.subtract(const Duration(days: 7));
    }

    // Split trips into current period and previous period
    final currentPeriodTrips = allTrips
        .where((trip) => trip.tripDate.isAfter(compareDate))
        .toList();
    final previousPeriodStart = compareDate.subtract(
      now.difference(compareDate),
    );
    final previousPeriodTrips = allTrips
        .where(
          (trip) =>
              trip.tripDate.isAfter(previousPeriodStart) &&
              trip.tripDate.isBefore(compareDate),
        )
        .toList();

    // Calculate trip count trend
    final currentTripsCount = currentPeriodTrips.length;
    final previousTripsCount = previousPeriodTrips.length;
    String tripsTrend;
    if (previousTripsCount == 0) {
      tripsTrend = currentTripsCount > 0 ? '+100%' : '0%';
    } else {
      final tripPercentChange =
          ((currentTripsCount - previousTripsCount) / previousTripsCount * 100)
              .round();
      tripsTrend = tripPercentChange >= 0
          ? '+$tripPercentChange%'
          : '$tripPercentChange%';
    }

    // Calculate miles trend
    double currentMiles = 0;
    double previousMiles = 0;
    for (final trip in currentPeriodTrips) {
      if (trip.totalDistance != null) currentMiles += trip.totalDistance!;
    }
    for (final trip in previousPeriodTrips) {
      if (trip.totalDistance != null) previousMiles += trip.totalDistance!;
    }

    String milesTrend;
    if (previousMiles == 0) {
      milesTrend = currentMiles > 0 ? '+100%' : '0%';
    } else {
      final milesPercentChange =
          ((currentMiles - previousMiles) / previousMiles * 100).round();
      milesTrend = milesPercentChange >= 0
          ? '+$milesPercentChange%'
          : '$milesPercentChange%';
    }

    return {'tripsTrend': tripsTrend, 'milesTrend': milesTrend};
  }

  /// Show dialog to change time period
  Future<void> _showTimePeriodDialog() async {
    final periods = {
      'weekly': 'Weekly',
      'biweekly': 'Bi-Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
    };

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Time Period',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: periods.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value, style: GoogleFonts.inter()),
              value: entry.key,
              groupValue: _timePeriod,
              activeColor: const Color(0xFF007AFF),
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  setState(() {
                    _timePeriod = value;
                  });
                  _loadDashboardStats();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Extract city and state from a full address using regex
  /// Examples:
  /// - "123 Main St, Los Angeles, CA 90001" -> "Los Angeles, CA"
  /// - "Toronto, ON, Canada" -> "Toronto, ON"
  /// - "New York" -> "New York"
  String _extractCityState(String address) {
    if (address.isEmpty) return address;

    // Pattern to match "City, State/Province" or "City, State ZIP"
    // Handles formats like:
    // - "City, ST" or "City, ST 12345"
    // - "City, Province" or "City, Province PostalCode"
    final RegExp cityStatePattern = RegExp(
      r'([A-Za-z\s]+),\s*([A-Z]{2})(?:\s+[A-Z0-9\s-]+)?(?:,|$)',
      caseSensitive: false,
    );

    final match = cityStatePattern.firstMatch(address);
    if (match != null) {
      final city = match.group(1)?.trim() ?? '';
      final state = match.group(2)?.toUpperCase() ?? '';
      if (city.isNotEmpty && state.isNotEmpty) {
        return '$city, $state';
      }
    }

    // If no match, try to extract just the city (first part before comma)
    final parts = address.split(',');
    if (parts.length >= 2) {
      // Take first significant part (skip if it looks like a street number)
      for (final part in parts) {
        final trimmed = part.trim();
        // Skip parts that start with numbers (likely street addresses)
        if (!RegExp(r'^\d').hasMatch(trimmed) && trimmed.isNotEmpty) {
          // If next part looks like a state code, include it
          final idx = parts.indexOf(part);
          if (idx + 1 < parts.length) {
            final nextPart = parts[idx + 1].trim();
            final stateMatch = RegExp(
              r'^([A-Z]{2})\b',
            ).firstMatch(nextPart.toUpperCase());
            if (stateMatch != null) {
              return '$trimmed, ${stateMatch.group(1)}';
            }
          }
          return trimmed;
        }
      }
    }

    // Return original if no pattern matched
    return address.length > 25 ? '${address.substring(0, 22)}...' : address;
  }

  Future<void> _loadPreferences() async {
    final showWeather = await PreferencesService.getShowWeather();
    setState(() {
      _showWeather = showWeather;
    });
  }

  Future<void> _loadBorderWaitTimes({bool forceRefresh = false}) async {
    final prefetch = DataPrefetchService.instance;

    // Try to use prefetched data first
    if (!forceRefresh &&
        prefetch.isPrefetchComplete &&
        prefetch.cachedBorderWaitTimes != null) {
      if (mounted) {
        setState(() {
          _borderWaitTimes = prefetch.cachedBorderWaitTimes!;
          _isLoadingBorders = false;
          _borderError = null;
        });
      }
      return;
    }

    if (forceRefresh) {
      setState(() {
        _isLoadingBorders = true;
        _borderError = null;
      });
    }
    try {
      // Force refresh the API data first if requested
      if (forceRefresh) {
        await BorderWaitTimeService.fetchAllWaitTimes(forceRefresh: true);
      }
      final waitTimes = await BorderWaitTimeService.getSavedBorderWaitTimes();
      if (mounted) {
        setState(() {
          _borderWaitTimes = waitTimes;
          _isLoadingBorders = false;
          _borderError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBorders = false;
          _borderError = _getErrorMessage(e);
        });
      }
    }
  }

  Future<void> _loadWeather() async {
    final showWeather = await PreferencesService.getShowWeather();
    if (!showWeather) {
      setState(() {
        _isLoadingWeather = false;
      });
      return;
    }

    try {
      final weather = await _weatherService.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
          _weatherError = weather == null ? 'Unable to get weather data' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _weatherError = _getErrorMessage(e);
        });
      }
    }
  }

  Future<void> _loadRecentEntries() async {
    try {
      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      List<FuelEntry> fuelEntries;

      // Use prefetched data if available, otherwise fetch
      if (prefetch.isPrefetchComplete &&
          prefetch.cachedTrips != null &&
          prefetch.cachedFuelEntries != null) {
        // Take first 5 from cached data
        trips = prefetch.cachedTrips!.take(5).toList();
        fuelEntries = prefetch.cachedFuelEntries!.take(5).toList();
      } else {
        trips = await TripService.getTrips(limit: 5);
        fuelEntries = await FuelService.getFuelEntries(limit: 5);
      }

      // Combine and sort by date
      final List<dynamic> combined = [];

      for (final trip in trips) {
        combined.add({'type': 'trip', 'data': trip, 'date': trip.tripDate});
      }

      for (final fuel in fuelEntries) {
        combined.add({'type': 'fuel', 'data': fuel, 'date': fuel.fuelDate});
      }

      // Sort by date descending
      combined.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      // Take only first 5
      final recent = combined.take(5).toList();

      if (mounted) {
        setState(() {
          _recentEntries = recent;
          _isLoadingEntries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEntries = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection') ||
        errorStr.contains('network')) {
      return 'No internet connection';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied';
    } else if (errorStr.contains('404')) {
      return 'Data not available';
    } else if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _toggleTemperatureUnit() {
    setState(() {
      _temperatureUnit = _temperatureUnit == 'C' ? 'F' : 'C';
    });
  }

  double _getDisplayTemperature() {
    if (_weatherData == null) return 0;
    final celsius = _weatherData!['temperature'] as double;
    if (_temperatureUnit == 'F') {
      return (celsius * 9 / 5) + 32;
    }
    return celsius;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF101828); // retained for subsequent widgets
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFD0D5DD);

    final margin = ResponsiveLayout.getMargin(context);
    final gutter = ResponsiveLayout.getGutter(context);
    final isTabletOrLarger = !ResponsiveLayout.isMobile(context);

    // Format total miles for display
    String formattedMiles;
    if (_totalMiles >= 1000) {
      formattedMiles = '${(_totalMiles / 1000).toStringAsFixed(1)}K';
    } else {
      formattedMiles = _totalMiles.toStringAsFixed(0);
    }
    final milesTitle = _distanceUnit == 'km' ? 'Km Driven' : 'Miles Driven';

    Widget statsGrid() => Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: isTabletOrLarger
          ? Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onLongPress: _showTimePeriodDialog,
                    child: DashboardCard(
                      value: '$_totalTrips',
                      title: 'Total Trips',
                      icon: Icons.local_shipping,
                      color: const Color(0xFF3B82F6),
                      trend: _tripsTrend,
                    ),
                  ),
                ),
                SizedBox(width: gutter),
                Expanded(
                  child: GestureDetector(
                    onLongPress: _showTimePeriodDialog,
                    child: DashboardCard(
                      value: formattedMiles,
                      title: milesTitle,
                      icon: Icons.route,
                      color: const Color(0xFF10B981),
                      trend: _milesTrend,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPress: _showTimePeriodDialog,
                        child: DashboardCard(
                          value: '$_totalTrips',
                          title: 'Total Trips',
                          icon: Icons.local_shipping,
                          color: const Color(0xFF3B82F6),
                          trend: _tripsTrend,
                        ),
                      ),
                    ),
                    SizedBox(width: gutter),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: _showTimePeriodDialog,
                        child: DashboardCard(
                          value: formattedMiles,
                          title: milesTitle,
                          icon: Icons.route,
                          color: const Color(0xFF10B981),
                          trend: _milesTrend,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

    Widget newsStrip(List<Map<String, String>> items) => SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        itemBuilder: (c, i) => SizedBox(
          width: context.responsive(xs: 180.0, sm: 200.0, md: 220.0),
          child: NewsCard(
            title: items[i]['title']!,
            source: items[i]['source']!,
          ),
        ),
        separatorBuilder: (_, _) => SizedBox(width: gutter),
        itemCount: items.length,
      ),
    );

    return AppScaffold(
      currentIndex: 1,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reduced top spacing after removing title
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Row(
                children: [
                  _quickAction(
                    cardColor,
                    borderColor,
                    secondaryTextColor,
                    Icons.search,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GlobalSearchPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Weather widget
                  if (_showWeather && _weatherData != null)
                    GestureDetector(
                      onTap: _toggleTemperatureUnit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _weatherService.getWeatherIcon(
                                _weatherData!['weatherCode'],
                                isDay: _weatherData!['isDay'] ?? true,
                              ),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_getDisplayTemperature().round()}°$_temperatureUnit',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showWeather && _isLoadingWeather && _weatherData == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (_showWeather &&
                      !_isLoadingWeather &&
                      _weatherData == null &&
                      _weatherError != null)
                    GestureDetector(
                      onTap: _loadWeather,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 20,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to retry',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Notification bell icon with red dot indicator
                  _buildNotificationBell(
                    cardColor,
                    borderColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  _quickAction(
                    const Color(0xFF007AFF),
                    const Color(0xFF007AFF),
                    Colors.white,
                    Icons.add,
                    () => context.push('/add-entry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            statsGrid(),
            const SizedBox(height: 16),
            // Border Wait Times Section
            if (_isLoadingBorders) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_borderError != null && _borderWaitTimes.isEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Border Wait Times Unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _borderError!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _loadBorderWaitTimes(forceRefresh: true),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_borderWaitTimes.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Border Wait Times',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _loadBorderWaitTimes(forceRefresh: true),
                      icon: Icon(
                        Icons.refresh,
                        size: 16,
                        color: const Color(0xFF007AFF),
                      ),
                      label: Text(
                        'Refresh',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Column(
                  children: _borderWaitTimes
                      .map((bwt) => BorderWaitTimeCard(waitTime: bwt))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Last Record Entries
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Record Entries',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: _isLoadingEntries
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _recentEntries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 48,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No entries yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add your first trip or fuel entry',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              ..._recentEntries.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final isTrip = item['type'] == 'trip';

                                Widget entryWidget;
                                if (isTrip) {
                                  final trip = item['data'] as Trip;
                                  final pickups = trip.pickupLocations;
                                  final deliveries = trip.deliveryLocations;
                                  final route =
                                      pickups.isNotEmpty &&
                                          deliveries.isNotEmpty
                                      ? '${_extractCityState(pickups.first)} → ${_extractCityState(deliveries.last)}'
                                      : 'No route';
                                  final distance = trip.totalDistance;
                                  final distanceStr = distance != null
                                      ? '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}'
                                      : '-';

                                  entryWidget = _buildRecordEntry(
                                    textColor,
                                    secondaryTextColor,
                                    'trip',
                                    'Trip #${trip.tripNumber}',
                                    route,
                                    DateFormat(
                                      'MMM d, yyyy',
                                    ).format(trip.tripDate),
                                    distanceStr,
                                  );
                                } else {
                                  final fuel = item['data'] as FuelEntry;
                                  final location = fuel.location != null
                                      ? _extractCityState(fuel.location!)
                                      : 'Unknown location';
                                  final quantity =
                                      '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}';
                                  final identifier = fuel.isTruckFuel
                                      ? fuel.truckNumber ?? 'Truck'
                                      : fuel.reeferNumber ?? 'Reefer';

                                  entryWidget = _buildRecordEntry(
                                    textColor,
                                    secondaryTextColor,
                                    'fuel',
                                    '${fuel.isTruckFuel ? "Truck" : "Reefer"} - $identifier',
                                    location,
                                    DateFormat(
                                      'MMM d, yyyy',
                                    ).format(fuel.fuelDate),
                                    quantity,
                                  );
                                }

                                return Column(
                                  children: [
                                    entryWidget,
                                    if (index < _recentEntries.length - 1)
                                      Divider(height: 1, color: borderColor),
                                  ],
                                );
                              }),
                              Divider(height: 1, color: borderColor),
                              // See more button
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RecordsListPage(),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'See more',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF007AFF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Trucking News',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewsListPage(
                    title: 'Trucking News',
                    items: [
                      {
                        'title': 'Major Highway Accident on I-95',
                        'source': 'Transport Weekly',
                      },
                      {
                        'title': 'Toll Rates Increase Nationwide',
                        'source': 'Trucking Today',
                      },
                      {
                        'title': 'New ELD Mandate Updates',
                        'source': 'DOT News',
                      },
                      {
                        'title': 'Fuel Prices Drop 10%',
                        'source': 'Industry Report',
                      },
                      {
                        'title': 'Winter Weather Advisory',
                        'source': 'Weather Channel',
                      },
                      {
                        'title': 'Driver Shortage Solutions',
                        'source': 'Fleet Management',
                      },
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            newsStrip(const [
              {
                'title': 'Major Highway Accident on I-95',
                'source': 'Transport Weekly',
              },
              {
                'title': 'Toll Rates Increase Nationwide',
                'source': 'Trucking Today',
              },
              {'title': 'New ELD Mandate Updates', 'source': 'DOT News'},
              {'title': 'Fuel Prices Drop 10%', 'source': 'Industry Report'},
              {'title': 'Winter Weather Advisory', 'source': 'Weather Channel'},
              {
                'title': 'Driver Shortage Solutions',
                'source': 'Fleet Management',
              },
            ]),
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Learning Pages',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewsListPage(
                    title: 'Learning Pages',
                    items: [
                      {'title': 'Safety Regulations 101', 'source': ''},
                      {'title': 'Route Planning Tips', 'source': ''},
                      {'title': 'Vehicle Maintenance Guide', 'source': ''},
                      {'title': 'Fuel Efficiency Best Practices', 'source': ''},
                      {'title': 'HOS Rules & Compliance', 'source': ''},
                      {'title': 'Load Securing Techniques', 'source': ''},
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            newsStrip(const [
              {'title': 'Safety Regulations 101', 'source': ''},
              {'title': 'Route Planning Tips', 'source': ''},
              {'title': 'Vehicle Maintenance Guide', 'source': ''},
              {'title': 'Fuel Efficiency Best Practices', 'source': ''},
              {'title': 'HOS Rules & Compliance', 'source': ''},
              {'title': 'Load Securing Techniques', 'source': ''},
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    Color bg,
    Color border,
    Color iconColor,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: bg == border ? null : Border.all(color: border),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildNotificationBell(
    Color cardColor,
    Color borderColor,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: () async {
        await context.push('/notifications');
        // Refresh notification count after returning from notifications page
        await NotificationService.instance.refreshUnreadCount();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_outlined, color: iconColor, size: 24),
            // Red dot indicator for unread notifications
            if (_unreadNotificationCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: cardColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordEntry(
    Color textColor,
    Color secondaryTextColor,
    String type,
    String entryId,
    String description,
    String date,
    String value,
  ) {
    final isTrip = type == 'trip';
    final iconColor = isTrip
        ? const Color(0xFF3B82F6)
        : const Color(0xFFF59E0B);
    final icon = isTrip ? Icons.local_shipping : Icons.local_gas_station;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                // Top row: Entry ID left, Value right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entryId,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Bottom row: Description left, Date right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
