import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/widgets/app_scaffold.dart';
import 'package:milow/core/widgets/dashboard_card.dart';
import 'package:milow/core/widgets/section_header.dart';
import 'package:milow/core/widgets/news_card.dart';
import 'package:milow/features/dashboard/presentation/pages/news_list_page.dart';
import 'package:milow/features/dashboard/presentation/pages/records_list_page.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/services/preferences_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWeather();
  }

  Future<void> _loadPreferences() async {
    final showWeather = await PreferencesService.getShowWeather();
    setState(() {
      _showWeather = showWeather;
    });
  }

  Future<void> _loadWeather() async {
    final showWeather = await PreferencesService.getShowWeather();
    if (!showWeather) {
      setState(() {
        _isLoadingWeather = false;
      });
      return;
    }

    final weather = await _weatherService.getCurrentWeather();
    setState(() {
      _weatherData = weather;
      _isLoadingWeather = false;
    });
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

    Widget statsGrid() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: const [
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  value: '127',
                  title: 'Total Loads',
                  icon: Icons.local_shipping,
                  color: Color(0xFF3B82F6),
                  trend: '+12%',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
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
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  value: '\$32.5K',
                  title: 'Revenue',
                  icon: Icons.attach_money,
                  color: Color(0xFF8B5CF6),
                  trend: '+15%',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DashboardCard(
                  value: '2.4h',
                  title: 'Avg Load Time',
                  icon: Icons.timer,
                  color: Color(0xFFF59E0B),
                  trend: '-5%',
                ),
              ),
            ],
          ),
        ],
      ),
    );

    Widget performanceChart() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
              : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Performance',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nov 23 - Nov 29',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+23%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBarChart('Mon', 0.6, Colors.white),
              _buildBarChart('Tue', 0.8, Colors.white),
              _buildBarChart('Wed', 0.7, Colors.white),
              _buildBarChart('Thu', 0.9, Colors.white),
              _buildBarChart('Fri', 0.85, Colors.white),
              _buildBarChart('Sat', 0.5, Colors.white.withValues(alpha: 0.6)),
              _buildBarChart('Sun', 0.3, Colors.white.withValues(alpha: 0.6)),
            ],
          ),
        ],
      ),
    );

    Widget newsStrip(List<Map<String, String>> items) => SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (c, i) => SizedBox(
          width: 180,
          child: NewsCard(
            title: items[i]['title']!,
            source: items[i]['source']!,
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
            performanceChart(),
            const SizedBox(height: 16),
            // Last Record Entries
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildBarChart(String label, double height, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 80 * height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
              color: iconColor.withOpacity(0.1),
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

  // _buildBarChart retained; other card/news logic migrated to reusable widgets.
}
