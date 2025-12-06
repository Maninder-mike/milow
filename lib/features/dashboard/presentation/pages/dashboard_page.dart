// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// TabsShell provides navigation; this page returns content only
import 'package:milow/core/widgets/dashboard_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:milow/core/widgets/section_header.dart';
import 'package:milow/core/widgets/news_card.dart';
import 'package:milow/core/widgets/border_wait_time_card.dart';
import 'package:milow/core/widgets/shimmer_loading.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
import 'package:milow/features/dashboard/presentation/pages/news_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/global_search_page.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/services/news_service.dart';
import 'package:milow/core/models/news_article.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
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
  List<NewsArticle> _newsArticles = [];
  bool _isLoadingNews = true;
  bool _showTruckingNews = false; // User preference
  Timer? _borderRefreshTimer;

  // Recent entries (trips and fuel)
  List<Map<String, dynamic>> _recentEntries = [];
  bool _isLoadingEntries = true;

  // Dashboard stats
  int _totalTrips = 0;
  double _totalMiles = 0;
  String _distanceUnit = 'mi';
  String _tripsTrend = '+0%';
  String _milesTrend = '+0%';
  String _timePeriod = 'biweekly'; // weekly, biweekly, monthly, yearly

  // Notification state
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;
  Timer? _webAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _loadWeather();
    _loadNews();
    _loadBorderWaitTimes(
      forceRefresh: false,
    ); // Use prefetched data if available
    _loadRecentEntries();
    _loadDashboardStats();
    _loadNotificationCount();
    // Web: auto-refresh periodically since pull-to-refresh isn't available
    if (kIsWeb) {
      _webAutoRefreshTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _onRefresh(),
      );
    }
    // Refresh border wait times every 5 minutes
    _borderRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadBorderWaitTimes(forceRefresh: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _borderRefreshTimer?.cancel();
    _notificationSubscription?.cancel();
    _webAutoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Pull-to-refresh handler - refreshes all dashboard data
  Future<void> _onRefresh() async {
    // Invalidate cache to force fresh data
    DataPrefetchService.instance.invalidateCache();

    // Refresh all data in parallel
    await Future.wait([
      _loadWeather(),
      _loadBorderWaitTimes(forceRefresh: true),
      _loadRecentEntries(),
      _loadDashboardStats(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload news when app resumes (e.g., returning from Settings)
    if (state == AppLifecycleState.resumed) {
      _loadNews();
    }
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
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Select Time Period',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
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
      },
    );
  }

  /// Extract city and state/province from address
  /// Returns format: "City ST" (e.g., "Vaughan ON" or "Irwindale CA")
  String _extractCityState(String address) {
    if (address.isEmpty) return address;

    // Normalize: replace newlines with commas for easier parsing
    final normalized = address
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r',\s*,'), ',');

    // Pattern 1: Match "CITY STATE ZIP" at end of segment
    // e.g., "IRWINDALE CA 91702" or "CHARLOTTETOWN PE C1E 0K4"
    final dispatchPattern = RegExp(
      r'([A-Z][A-Z\s]*?)\s+([A-Z]{2})\s+[A-Z0-9]{3,7}(?:\s*[A-Z0-9]{0,4})?\s*$',
      caseSensitive: false,
    );

    final segments = normalized.split(',');
    for (final segment in segments) {
      final trimmed = segment.trim();
      final dispatchMatch = dispatchPattern.firstMatch(trimmed.toUpperCase());
      if (dispatchMatch != null) {
        // Get the last word(s) before state - extract city from end
        final rawCity = dispatchMatch.group(1)!.trim();
        final city = _extractLastCity(rawCity);
        final state = dispatchMatch.group(2)!.toUpperCase();
        return '$city $state';
      }
    }

    // Pattern 2: Match "CITY STATE" followed by ( or end (e.g., "VAUGHAN ON (Yard)")
    final cityStateParenPattern = RegExp(
      r'([A-Z][A-Z\s]*?)\s+([A-Z]{2})\s*(?:\(|$)',
      caseSensitive: false,
    );
    for (final segment in segments) {
      final trimmed = segment.trim();
      final match = cityStateParenPattern.firstMatch(trimmed.toUpperCase());
      if (match != null) {
        final rawCity = match.group(1)!.trim();
        final city = _extractLastCity(rawCity);
        final state = match.group(2)!.toUpperCase();
        return '$city $state';
      }
    }

    // Pattern 3: Standard format "City, ST" or "City, ST ZIP"
    final cityStatePattern = RegExp(
      r'([A-Za-z][A-Za-z\s]+?),\s*([A-Z]{2})(?:\s+[A-Z0-9\s-]+)?(?:,|$)',
      caseSensitive: false,
    );
    final match = cityStatePattern.firstMatch(normalized);
    if (match != null) {
      final city = _toTitleCase(match.group(1)!.trim());
      final state = match.group(2)!.toUpperCase();
      return '$city $state';
    }

    // Fallback: just return first non-numeric part abbreviated
    final parts = normalized.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (!RegExp(r'^\d').hasMatch(trimmed) && trimmed.isNotEmpty) {
        return trimmed.length > 20 ? '${trimmed.substring(0, 17)}...' : trimmed;
      }
    }

    return address.length > 20 ? '${address.substring(0, 17)}...' : address;
  }

  /// Extract the actual city name from a string that might include street names
  /// e.g., "COLD CREEK ROAD VAUGHAN" -> "Vaughan"
  /// e.g., "QUEBEC CITY" -> "Quebec City"
  String _extractLastCity(String raw) {
    final words = raw.split(RegExp(r'\s+'));
    if (words.isEmpty) return _toTitleCase(raw);

    // Common street suffixes to skip
    final streetSuffixes = {
      'ROAD',
      'RD',
      'STREET',
      'ST',
      'AVENUE',
      'AVE',
      'BLVD',
      'BOULEVARD',
      'DRIVE',
      'DR',
      'LANE',
      'LN',
      'WAY',
      'COURT',
      'CT',
      'PLACE',
      'PL',
      'CIRCLE',
      'CIR',
      'HIGHWAY',
      'HWY',
      'ROUTE',
      'RTE',
      'PARKWAY',
      'PKWY',
    };

    // Find the last street suffix and take everything after it
    int lastStreetIndex = -1;
    for (int i = 0; i < words.length; i++) {
      if (streetSuffixes.contains(words[i].toUpperCase())) {
        lastStreetIndex = i;
      }
    }

    if (lastStreetIndex >= 0 && lastStreetIndex < words.length - 1) {
      // Take everything after the last street suffix
      final cityWords = words.sublist(lastStreetIndex + 1);
      return _toTitleCase(cityWords.join(' '));
    }

    // If no street suffix found, check if first word looks like a number (street address)
    if (words.length > 1 && RegExp(r'^\d').hasMatch(words.first)) {
      // Skip the street number and take the last 1-2 words as city
      final cityWords = words.length > 2
          ? words.sublist(words.length - 2)
          : [words.last];
      // But if second-to-last is a street suffix, just take last word
      if (cityWords.length > 1 &&
          streetSuffixes.contains(cityWords.first.toUpperCase())) {
        return _toTitleCase(cityWords.last);
      }
      return _toTitleCase(cityWords.join(' '));
    }

    // Return the whole thing as city (e.g., "QUEBEC CITY")
    return _toTitleCase(raw);
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
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
          _recentEntries = List<Map<String, dynamic>>.from(recent);
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

  Future<void> _loadNews() async {
    // Check if trucking news is enabled
    final showNews = await PreferencesService.getShowTruckingNews();

    if (mounted) {
      setState(() {
        _showTruckingNews = showNews;
      });
    }

    if (!showNews) {
      // User has disabled trucking news, keep the list empty
      if (mounted) {
        setState(() {
          _newsArticles = [];
          _isLoadingNews = false;
        });
      }
      return;
    }

    try {
      final news = await NewsService.getTruckingNews();
      if (mounted) {
        setState(() {
          _newsArticles = news;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Keep empty list if failed, maybe show cached if available logic is in service
          _isLoadingNews = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      // Try launching in in-app browser first
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        // Fallback to external application (browser) if in-app fails
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error safely
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

    Widget newsStrip(List<NewsArticle> items) => SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        itemBuilder: (c, i) => SizedBox(
          width: context.responsive(xs: 180.0, sm: 200.0, md: 220.0),
          child: NewsCard(
            title: items[i].title,
            source: items[i].source,
            onTap: () => _launchUrl(items[i].url ?? ''),
          ),
        ),
        separatorBuilder: (_, _) => SizedBox(width: gutter),
        itemCount: items.length,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f23),
                ]
              : [
                  const Color(0xFFe8f4f8),
                  const Color(0xFFfce4ec),
                  const Color(0xFFe8f5e9),
                ],
        ),
      ),
      child: Shimmer(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 60,
          strokeWidth: 3.0,
          color: const Color(0xFF007AFF),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      // Weather loads silently in background, only show when ready
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
                    child: const ShimmerLoading(
                      isLoading: true,
                      child: Column(
                        children: [
                          ShimmerBorderWaitCard(),
                          ShimmerBorderWaitCard(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_borderError != null &&
                    _borderWaitTimes.isEmpty) ...[
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
                          onPressed: () =>
                              _loadBorderWaitTimes(forceRefresh: true),
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Color(0xFF007AFF),
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
                            ? const ShimmerLoading(
                                isLoading: true,
                                child: Column(
                                  children: [
                                    ShimmerEntryItem(),
                                    ShimmerEntryItem(),
                                    ShimmerEntryItem(),
                                    ShimmerEntryItem(showDivider: false),
                                  ],
                                ),
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
                                  ..._recentEntries.asMap().entries.map((
                                    entry,
                                  ) {
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
                                          Divider(
                                            height: 1,
                                            color: borderColor,
                                          ),
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
                // Only show Trucking News section if enabled in settings
                if (_showTruckingNews) ...[
                  SectionHeader(
                    title: 'Trucking News',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsListPage(
                          title: 'Trucking News',
                          // Pass real articles if possible, or let NewsListPage fetch them too?
                          // Simplified: Pass the current _newsArticles list
                          items: _newsArticles
                              .map(
                                (article) => {
                                  'title': article.title,
                                  'source': article.source,
                                  'url': article.url ?? '',
                                  'date': article.publishedAt != null
                                      ? DateFormat(
                                          'MMM d',
                                        ).format(article.publishedAt!)
                                      : '',
                                  'description': article.description ?? '',
                                },
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingNews)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_newsArticles.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: margin),
                      child: Text(
                        'No news available',
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    newsStrip(_newsArticles),
                  const SizedBox(height: 16),
                ],
                const SectionHeader(title: 'Learning Pages'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: margin),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 32,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Learning Resources Coming Soon',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We are working on great educational content for you.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Extra padding for floating bottom nav bar
                const SizedBox(height: 120),
              ],
            ),
          ),
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
