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
import 'package:milow/features/dashboard/presentation/pages/news_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/utils/responsive_layout.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWeather();
    _loadBorderWaitTimes(forceRefresh: true); // Force refresh on first load
    // Refresh border wait times every 5 minutes
    _borderRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadBorderWaitTimes(forceRefresh: true),
    );
  }

  @override
  void dispose() {
    _borderRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final showWeather = await PreferencesService.getShowWeather();
    setState(() {
      _showWeather = showWeather;
    });
  }

  Future<void> _loadBorderWaitTimes({bool forceRefresh = false}) async {
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

    Widget statsGrid() => Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: isTabletOrLarger
          ? Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    value: '127',
                    title: 'Total Loads',
                    icon: Icons.local_shipping,
                    color: const Color(0xFF3B82F6),
                    trend: '+12%',
                  ),
                ),
                SizedBox(width: gutter),
                Expanded(
                  child: DashboardCard(
                    value: '45.2K',
                    title: 'Miles Driven',
                    icon: Icons.route,
                    color: const Color(0xFF10B981),
                    trend: '+8%',
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: DashboardCard(
                        value: '127',
                        title: 'Total Loads',
                        icon: Icons.local_shipping,
                        color: Color(0xFF3B82F6),
                        trend: '+12%',
                      ),
                    ),
                    SizedBox(width: gutter),
                    const Expanded(
                      child: DashboardCard(
                        value: '45.2K',
                        title: 'Miles Driven',
                        icon: Icons.route,
                        color: Color(0xFF10B981),
                        trend: '+8%',
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
                    () {},
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
                    child: Column(
                      children: [
                        _buildRecordEntry(
                          textColor,
                          secondaryTextColor,
                          'trip',
                          'Trip #1247',
                          'Dallas → Houston',
                          'Nov 29, 2025',
                          '245 mi',
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildRecordEntry(
                          textColor,
                          secondaryTextColor,
                          'fuel',
                          'Fuel #F-892',
                          'Shell Station, Austin',
                          'Nov 28, 2025',
                          '85 gal',
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildRecordEntry(
                          textColor,
                          secondaryTextColor,
                          'trip',
                          'Trip #1246',
                          'Austin → San Antonio',
                          'Nov 28, 2025',
                          '80 mi',
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildRecordEntry(
                          textColor,
                          secondaryTextColor,
                          'fuel',
                          'Fuel #F-891',
                          'Pilot, Phoenix',
                          'Nov 27, 2025',
                          '120 gal',
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildRecordEntry(
                          textColor,
                          secondaryTextColor,
                          'trip',
                          'Trip #1245',
                          'Phoenix → Tucson',
                          'Nov 27, 2025',
                          '116 mi',
                        ),
                        Divider(height: 1, color: borderColor),
                        // See more button
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecordsListPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entryId,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
