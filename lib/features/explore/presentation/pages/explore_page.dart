import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
// Tab shell provides nav; this page returns content only
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:intl/intl.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Trip> _allTrips = [];
  List<FuelEntry> _allFuelEntries = [];
  bool _isLoading = true;
  String _selectedCategory = 'All Routes';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    DataPrefetchService.instance.invalidateCache();
    await _loadData();
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

  Future<void> _loadData() async {
    try {
      final prefetch = DataPrefetchService.instance;
      List<Trip> trips;
      List<FuelEntry> fuelEntries;

      if (prefetch.isPrefetchComplete &&
          prefetch.cachedTrips != null &&
          prefetch.cachedFuelEntries != null) {
        trips = prefetch.cachedTrips!;
        fuelEntries = prefetch.cachedFuelEntries!;
      } else {
        trips = await TripService.getTrips();
        fuelEntries = await FuelService.getFuelEntries();
      }

      if (mounted) {
        setState(() {
          _allTrips = trips;
          _allFuelEntries = fuelEntries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Trip> get _filteredTrips {
    switch (_selectedCategory) {
      case 'Long Haul':
        // Over 500 miles
        return _allTrips.where((t) {
          final distance = t.totalDistance ?? 0;
          return distance > 500;
        }).toList();
      case 'Regional':
        // 200 to 500 miles
        return _allTrips.where((t) {
          final distance = t.totalDistance ?? 0;
          return distance >= 200 && distance <= 500;
        }).toList();
      case 'Local':
        // Less than 200 miles
        return _allTrips.where((t) {
          final distance = t.totalDistance ?? 0;
          return distance < 200 && distance > 0;
        }).toList();
      default:
        return _allTrips;
    }
  }

  /// Get popular destinations filtered by category
  List<Map<String, dynamic>> get _filteredDestinations {
    final trips = _filteredTrips;
    final cityData = <String, Map<String, dynamic>>{};

    for (final trip in trips) {
      for (final loc in [...trip.pickupLocations, ...trip.deliveryLocations]) {
        final city = _extractCityState(loc);
        if (city.isNotEmpty) {
          if (!cityData.containsKey(city)) {
            cityData[city] = {
              'city': city,
              'count': 0,
              'trips': <Trip>[],
              'totalMiles': 0.0,
            };
          }
          cityData[city]!['count'] = (cityData[city]!['count'] as int) + 1;
          final tripsList = cityData[city]!['trips'] as List<Trip>;
          if (!tripsList.contains(trip)) {
            tripsList.add(trip);
            if (trip.totalDistance != null) {
              cityData[city]!['totalMiles'] =
                  (cityData[city]!['totalMiles'] as double) +
                  trip.totalDistance!;
            }
          }
        }
      }
    }

    final sortedCities = cityData.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return sortedCities.take(5).map((e) {
      final count = e['count'] as int;
      return {
        'city': e['city'],
        'count': count,
        'description': '$count ${count == 1 ? 'trip' : 'trips'}',
        'trips': e['trips'],
        'totalMiles': e['totalMiles'],
      };
    }).toList();
  }

  /// Get recent activity filtered by category
  List<Map<String, dynamic>> get _filteredActivity {
    final trips = _filteredTrips;
    final List<Map<String, dynamic>> activity = [];

    for (final trip in trips.take(5)) {
      final route =
          trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
          ? '${_extractCityState(trip.pickupLocations.first)} → ${_extractCityState(trip.deliveryLocations.last)}'
          : 'Trip ${trip.tripNumber}';
      activity.add({
        'type': 'trip',
        'title': 'Trip ${trip.tripNumber}',
        'subtitle': route,
        'date': trip.createdAt ?? trip.tripDate,
        'icon': Icons.local_shipping,
        'trip': trip, // Include full trip object
      });
    }

    // Only include fuel entries when showing all routes
    if (_selectedCategory == 'All Routes') {
      for (final fuel in _allFuelEntries.take(5)) {
        final location = fuel.location != null
            ? _extractCityState(fuel.location!)
            : 'Unknown location';
        activity.add({
          'type': 'fuel',
          'title': fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
          'subtitle':
              '$location • ${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
          'date': fuel.createdAt ?? fuel.fuelDate,
          'icon': Icons.local_gas_station,
          'fuel': fuel, // Include full fuel object
        });
      }
    }

    activity.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    return activity.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f1a),
                  ]
                : [
                    const Color(0xFFF0F4FF),
                    const Color(0xFFFDF2F8),
                    const Color(0xFFF0FDF4),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 60,
          strokeWidth: 3.0,
          color: const Color(0xFF6C5CE7),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                floating: true,
                snap: true,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)?.explore ?? 'Explore',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.search, color: textColor),
                      onPressed: () => _showSearchDialog(),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'CATEGORIES'),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCategoryChip(
                                    'All Routes',
                                    Icons.route,
                                    _selectedCategory == 'All Routes',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    'Long Haul',
                                    Icons.local_shipping,
                                    _selectedCategory == 'Long Haul',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    'Regional',
                                    Icons.map_outlined,
                                    _selectedCategory == 'Regional',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    'Local',
                                    Icons.location_on_outlined,
                                    _selectedCategory == 'Local',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeaderRow(
                              title: 'Popular Destinations',
                              onAction: _filteredDestinations.isNotEmpty
                                  ? () => _navigateToAllDestinations()
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (_filteredDestinations.isEmpty)
                              _EmptyStateCard(
                                message: _selectedCategory == 'All Routes'
                                    ? 'No destinations yet.'
                                    : 'No destinations for $_selectedCategory trips.',
                                icon: Icons.location_city,
                              )
                            else
                              Column(
                                children: _filteredDestinations.take(5).map((
                                  dest,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SimpleDestinationCard(
                                      destination: dest,
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 24),
                            _SectionHeaderRow(
                              title: 'Recent Activity',
                              onAction: _filteredActivity.isNotEmpty
                                  ? () => _navigateToAllActivity()
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (_filteredActivity.isEmpty)
                              _EmptyStateCard(
                                message: _selectedCategory == 'All Routes'
                                    ? 'No recent activity.'
                                    : 'No recent $_selectedCategory activity.',
                                icon: Icons.history,
                              )
                            else
                              Column(
                                children: _filteredActivity.take(5).map((
                                  activity,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SimpleActivityCard(
                                      activity: activity,
                                    ),
                                  );
                                }).toList(),
                              ),
                            // Extra padding for floating bottom nav bar
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6C5CE7)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6C5CE7)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : const Color(0xFF667085),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : isDark
                        ? Colors.white
                        : const Color(0xFF101828),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _SearchDialog(trips: _allTrips, extractCityState: _extractCityState),
    );
  }

  void _navigateToAllDestinations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllDestinationsPage(
          destinations: _filteredDestinations,
          categoryLabel: _selectedCategory,
          extractCityState: _extractCityState,
        ),
      ),
    );
  }

  void _navigateToAllActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllActivityPage(
          trips: _filteredTrips,
          fuelEntries: _selectedCategory == 'All Routes' ? _allFuelEntries : [],
          extractCityState: _extractCityState,
          categoryLabel: _selectedCategory,
        ),
      ),
    );
  }
}

// ============== Helper Widgets ==============

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<DesignTokens>() ?? DesignTokens.light;
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tokens.sectionLabelColor,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  const _SectionHeaderRow({required this.title, this.onAction});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              'See all',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyStateCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.7),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF9CA3AF), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== Simple Cards for Explore Page ==============

class _GlassyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassyCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SimpleDestinationCard extends StatelessWidget {
  final Map<String, dynamic> destination;

  const _SimpleDestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF667085);
    final city = destination['city'] as String;
    final count = destination['count'] as int;
    final description = destination['description'] as String;

    return _GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_city,
              color: Color(0xFFF59E0B),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(fontSize: 13, color: subtitleColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6C5CE7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _SimpleActivityCard({required this.activity});

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF667085);
    final icon = activity['icon'] as IconData;
    final isTrip = icon == Icons.local_shipping;
    final iconColor = isTrip
        ? const Color(0xFF6C5CE7)
        : const Color(0xFF10B981);
    final date = activity['date'] as DateTime;

    return _GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['subtitle'] as String,
                  style: GoogleFonts.inter(fontSize: 13, color: subtitleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(date),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== Expandable Cards for See All Pages ==============

class _ExpandableRouteCard extends StatefulWidget {
  final Trip trip;
  final String Function(String) extractCityState;

  const _ExpandableRouteCard({
    required this.trip,
    required this.extractCityState,
  });

  @override
  State<_ExpandableRouteCard> createState() => _ExpandableRouteCardState();
}

class _ExpandableRouteCardState extends State<_ExpandableRouteCard> {
  bool _isExpanded = false;

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Color _getDistanceColor(double? distance) {
    if (distance == null) return const Color(0xFF9CA3AF);
    if (distance > 500) return const Color(0xFF3B82F6); // Long Haul - blue
    if (distance >= 200) return const Color(0xFFF59E0B); // Regional - amber
    return const Color(0xFF10B981); // Local - green
  }

  String _getDistanceCategory(double? distance) {
    if (distance == null) return '';
    if (distance > 500) return 'Long Haul';
    if (distance >= 200) return 'Regional';
    return 'Local';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final accentColor = const Color(0xFF3B82F6);

    final trip = widget.trip;
    final route =
        trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
        ? '${widget.extractCityState(trip.pickupLocations.first)} → ${widget.extractCityState(trip.deliveryLocations.last)}'
        : 'No route';
    final distance = trip.totalDistance;
    final distanceColor = _getDistanceColor(distance);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Distance section
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            distance != null
                                ? distance.toStringAsFixed(0)
                                : '--',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip.distanceUnitLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: distanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(width: 1, height: 50, color: dividerColor),
                    const SizedBox(width: 16),
                    // Trip info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip ${trip.tripNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            route,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Expand icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Expanded content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(
                  isDark: isDark,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  dividerColor: dividerColor,
                  accentColor: accentColor,
                  distanceColor: distanceColor,
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color dividerColor,
    required Color accentColor,
    required Color distanceColor,
  }) {
    final trip = widget.trip;
    final distance = trip.totalDistance;
    final category = _getDistanceCategory(distance);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // Trip details section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trip Details',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: distanceColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _formatDate(trip.tripDate),
                        textColor: textColor,
                        subtextColor: subtextColor,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.directions_car_outlined,
                        label: 'Truck',
                        value: trip.truckNumber,
                        textColor: textColor,
                        subtextColor: subtextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Odometer section
          if (trip.startOdometer != null || trip.endOdometer != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_outlined,
                    size: 18,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Odometer',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${trip.startOdometer?.toStringAsFixed(0) ?? '--'} → ${trip.endOdometer?.toStringAsFixed(0) ?? '--'} ${trip.distanceUnitLabel}',
                    style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
                  ),
                ],
              ),
            ),

          if (trip.startOdometer != null || trip.endOdometer != null)
            const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Expanded(
                child: _buildLocationChip(
                  icon: Icons.trip_origin,
                  label: 'Pickups',
                  locations: trip.pickupLocations,
                  color: const Color(0xFF3B82F6),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationChip(
                  icon: Icons.flag_outlined,
                  label: 'Deliveries',
                  locations: trip.deliveryLocations,
                  color: const Color(0xFFF59E0B),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          // Trailers
          if (trip.trailers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.rv_hookup, size: 18, color: subtextColor),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ',
                    style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
                  ),
                  Expanded(
                    child: Text(
                      trip.trailers.join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notes
          if (trip.notes != null && trip.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_outlined,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subtextColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationChip({
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$label (${locations.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...locations
              .take(2)
              .map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    widget.extractCityState(loc),
                    style: GoogleFonts.inter(fontSize: 12, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
            ),
        ],
      ),
    );
  }
}

class _ExpandableDestinationCard extends StatefulWidget {
  final Map<String, dynamic> destination;
  final String Function(String) extractCityState;

  const _ExpandableDestinationCard({
    required this.destination,
    required this.extractCityState,
  });

  @override
  State<_ExpandableDestinationCard> createState() =>
      _ExpandableDestinationCardState();
}

class _ExpandableDestinationCardState
    extends State<_ExpandableDestinationCard> {
  bool _isExpanded = false;

  String _formatDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final accentColor = const Color(0xFFF59E0B);

    final city = widget.destination['city'] as String;
    final count = widget.destination['count'] as int;
    final trips = widget.destination['trips'] as List<Trip>? ?? [];
    final totalMiles = widget.destination['totalMiles'] as double? ?? 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Count section
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            count == 1 ? 'trip' : 'trips',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // City info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (totalMiles > 0)
                            Text(
                              '${totalMiles.toStringAsFixed(0)} miles total',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: subtextColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Expand icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Expanded content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(
                  isDark: isDark,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  dividerColor: dividerColor,
                  accentColor: accentColor,
                  trips: trips,
                  totalMiles: totalMiles,
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color dividerColor,
    required Color accentColor,
    required List<Trip> trips,
    required double totalMiles,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Trips',
                  value: '${trips.length}',
                  color: const Color(0xFF3B82F6),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.straighten_outlined,
                  label: 'Total Distance',
                  value: '${totalMiles.toStringAsFixed(0)} mi',
                  color: const Color(0xFF10B981),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          if (trips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.history, size: 16, color: subtextColor),
                const SizedBox(width: 8),
                Text(
                  'Recent Trips to this location',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...trips.take(3).map((trip) {
              final route =
                  trip.pickupLocations.isNotEmpty &&
                      trip.deliveryLocations.isNotEmpty
                  ? '${widget.extractCityState(trip.pickupLocations.first)} → ${widget.extractCityState(trip.deliveryLocations.last)}'
                  : 'Trip ${trip.tripNumber}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        size: 18,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip ${trip.tripNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          Text(
                            route,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(trip.tripDate),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                        if (trip.totalDistance != null)
                          Text(
                            '${trip.totalDistance!.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (trips.length > 3)
              Text(
                '+${trips.length - 3} more trips',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpandableActivityCard extends StatefulWidget {
  final Map<String, dynamic> activity;
  final String Function(String) extractCityState;

  const _ExpandableActivityCard({
    required this.activity,
    required this.extractCityState,
  });

  @override
  State<_ExpandableActivityCard> createState() =>
      _ExpandableActivityCardState();
}

class _ExpandableActivityCardState extends State<_ExpandableActivityCard> {
  bool _isExpanded = false;

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final isTrip = widget.activity['type'] == 'trip';
    final accentColor = isTrip
        ? const Color(0xFF3B82F6)
        : const Color(0xFF10B981);
    final date = widget.activity['date'] as DateTime;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon section
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.activity['icon'] as IconData,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activity['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.activity['subtitle'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Time ago
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimeAgo(date),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: subtextColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Expanded content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: isTrip
                    ? _buildTripExpandedContent(
                        isDark: isDark,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        dividerColor: dividerColor,
                        accentColor: accentColor,
                      )
                    : _buildFuelExpandedContent(
                        isDark: isDark,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        dividerColor: dividerColor,
                        accentColor: accentColor,
                      ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripExpandedContent({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color dividerColor,
    required Color accentColor,
  }) {
    final trip = widget.activity['trip'] as Trip?;
    if (trip == null) return const SizedBox.shrink();

    final distance = trip.totalDistance;
    Color distanceColor;
    String category;
    if (distance == null) {
      distanceColor = const Color(0xFF9CA3AF);
      category = '';
    } else if (distance > 500) {
      distanceColor = const Color(0xFF3B82F6);
      category = 'Long Haul';
    } else if (distance >= 200) {
      distanceColor = const Color(0xFFF59E0B);
      category = 'Regional';
    } else {
      distanceColor = const Color(0xFF10B981);
      category = 'Local';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // Trip overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(trip.tripDate),
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                    _buildInfoItem(
                      icon: Icons.directions_car_outlined,
                      label: 'Truck',
                      value: trip.truckNumber,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                    if (distance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: distanceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (category.isNotEmpty)
                              Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Expanded(
                child: _buildLocationInfo(
                  icon: Icons.trip_origin,
                  label: 'From',
                  locations: trip.pickupLocations,
                  color: const Color(0xFF3B82F6),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationInfo(
                  icon: Icons.flag_outlined,
                  label: 'To',
                  locations: trip.deliveryLocations,
                  color: const Color(0xFFF59E0B),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          // Trailers
          if (trip.trailers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.rv_hookup, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ${trip.trailers.join(', ')}',
                    style: GoogleFonts.inter(fontSize: 13, color: textColor),
                  ),
                ],
              ),
            ),
          ],

          // Notes
          if (trip.notes != null && trip.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFuelExpandedContent({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color dividerColor,
    required Color accentColor,
  }) {
    final fuel = widget.activity['fuel'] as FuelEntry?;
    if (fuel == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),

          // Fuel overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(fuel.fuelDate),
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        fuel.formattedTotalCost,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Fuel details grid
          Row(
            children: [
              Expanded(
                child: _buildFuelDetailCard(
                  icon: Icons.local_gas_station_outlined,
                  label: 'Quantity',
                  value:
                      '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
                  color: const Color(0xFF3B82F6),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFuelDetailCard(
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: fuel.formattedPricePerUnit,
                  color: const Color(0xFF10B981),
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Additional info
          Row(
            children: [
              if (fuel.isTruckFuel && fuel.truckNumber != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    icon: Icons.local_shipping_outlined,
                    label: 'Truck',
                    value: fuel.truckNumber!,
                    color: const Color(0xFFF59E0B),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferNumber != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    icon: Icons.ac_unit_outlined,
                    label: 'Reefer',
                    value: fuel.reeferNumber!,
                    color: const Color(0xFFF59E0B),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              if (fuel.isTruckFuel && fuel.odometerReading != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    icon: Icons.speed_outlined,
                    label: 'Odometer',
                    value:
                        '${fuel.odometerReading!.toStringAsFixed(0)} ${fuel.distanceUnitLabel}',
                    color: const Color(0xFF8B5CF6),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferHours != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    icon: Icons.timer_outlined,
                    label: 'Reefer Hours',
                    value: fuel.reeferHours!.toStringAsFixed(1),
                    color: const Color(0xFF8B5CF6),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),

          // Location
          if (fuel.location != null && fuel.location!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fuel.location!,
                      style: GoogleFonts.inter(fontSize: 13, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: subtextColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfo({
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$label (${locations.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...locations
              .take(2)
              .map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    widget.extractCityState(loc),
                    style: GoogleFonts.inter(fontSize: 12, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============== See All Pages ==============

class _AllDestinationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;
  final String categoryLabel;
  final String Function(String) extractCityState;

  const _AllDestinationsPage({
    required this.destinations,
    required this.categoryLabel,
    required this.extractCityState,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          categoryLabel == 'All Routes'
              ? 'Popular Destinations'
              : '$categoryLabel Destinations',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF101828),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF101828),
        ),
      ),
      body: destinations.isEmpty
          ? Center(
              child: Text(
                categoryLabel == 'All Routes'
                    ? 'No destinations found'
                    : 'No destinations for $categoryLabel trips',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                return _ExpandableDestinationCard(
                  destination: dest,
                  extractCityState: extractCityState,
                );
              },
            ),
    );
  }
}

class _AllActivityPage extends StatefulWidget {
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;
  final String Function(String) extractCityState;
  final String categoryLabel;

  const _AllActivityPage({
    required this.trips,
    required this.fuelEntries,
    required this.extractCityState,
    required this.categoryLabel,
  });

  @override
  State<_AllActivityPage> createState() => _AllActivityPageState();
}

class _AllActivityPageState extends State<_AllActivityPage> {
  late List<Map<String, dynamic>> _activity;

  @override
  void initState() {
    super.initState();
    _buildActivityList();
  }

  void _buildActivityList() {
    _activity = [];

    for (final trip in widget.trips) {
      final route =
          trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
          ? '${widget.extractCityState(trip.pickupLocations.first)} → ${widget.extractCityState(trip.deliveryLocations.last)}'
          : 'Trip ${trip.tripNumber}';
      _activity.add({
        'type': 'trip',
        'title': 'Trip ${trip.tripNumber}',
        'subtitle': route,
        'date': trip.createdAt ?? trip.tripDate,
        'icon': Icons.local_shipping,
        'trip': trip,
      });
    }

    for (final fuel in widget.fuelEntries) {
      final location = fuel.location != null
          ? widget.extractCityState(fuel.location!)
          : 'Unknown location';
      _activity.add({
        'type': 'fuel',
        'title': fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
        'subtitle':
            '$location • ${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
        'date': fuel.createdAt ?? fuel.fuelDate,
        'icon': Icons.local_gas_station,
        'fuel': fuel,
      });
    }

    _activity.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item, int index) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isTrip = item['type'] == 'trip';
    final title = item['title'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete ${isTrip ? 'Trip' : 'Fuel Entry'}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete $title?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF667085)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (isTrip) {
          final trip = item['trip'] as Trip;
          if (trip.id != null) {
            await TripService.deleteTrip(trip.id!);
          }
        } else {
          final fuel = item['fuel'] as FuelEntry;
          if (fuel.id != null) {
            await FuelService.deleteFuelEntry(fuel.id!);
          }
        }

        DataPrefetchService.instance.invalidateCache();

        setState(() {
          _activity.removeAt(index);
        });

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('$title deleted'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _modifyItem(Map<String, dynamic> item) async {
    final isTrip = item['type'] == 'trip';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryPage(
          editingTrip: isTrip ? item['trip'] as Trip : null,
          editingFuel: !isTrip ? item['fuel'] as FuelEntry : null,
          initialTab: isTrip ? 0 : 1,
        ),
      ),
    );

    if (result == true) {
      DataPrefetchService.instance.invalidateCache();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          widget.categoryLabel == 'All Routes'
              ? 'All Activity'
              : '${widget.categoryLabel} Activity',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF101828),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF101828),
        ),
      ),
      body: _activity.isEmpty
          ? Center(
              child: Text(
                widget.categoryLabel == 'All Routes'
                    ? 'No activity found'
                    : 'No ${widget.categoryLabel} activity found',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activity.length,
              itemBuilder: (context, index) {
                final item = _activity[index];
                final isTrip = item['type'] == 'trip';

                return Dismissible(
                  key: Key(
                    '${item['type']}_${isTrip ? (item['trip'] as Trip).id : (item['fuel'] as FuelEntry).id}_$index',
                  ),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Modify',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.delete, color: Colors.white),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      await _deleteItem(item, index);
                      return false;
                    } else {
                      await _modifyItem(item);
                      return false;
                    }
                  },
                  child: _ExpandableActivityCard(
                    activity: item,
                    extractCityState: widget.extractCityState,
                  ),
                );
              },
            ),
    );
  }
}

// ============== Search Dialog ==============

class _SearchDialog extends StatefulWidget {
  final List<Trip> trips;
  final String Function(String) extractCityState;

  const _SearchDialog({required this.trips, required this.extractCityState});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _searchController = TextEditingController();
  List<Trip> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = widget.trips.where((trip) {
      return trip.tripNumber.toLowerCase().contains(lowerQuery) ||
          trip.truckNumber.toLowerCase().contains(lowerQuery) ||
          trip.pickupLocations.any(
            (l) => l.toLowerCase().contains(lowerQuery),
          ) ||
          trip.deliveryLocations.any(
            (l) => l.toLowerCase().contains(lowerQuery),
          );
    }).toList();

    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search trips, locations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search'
                            : 'No results found',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final trip = _results[index];
                        final route =
                            trip.pickupLocations.isNotEmpty &&
                                trip.deliveryLocations.isNotEmpty
                            ? '${widget.extractCityState(trip.pickupLocations.first)} → ${widget.extractCityState(trip.deliveryLocations.last)}'
                            : 'No route';
                        return ListTile(
                          leading: const Icon(
                            Icons.local_shipping,
                            color: Color(0xFF007AFF),
                          ),
                          title: Text(
                            'Trip ${trip.tripNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            route,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          onTap: () => Navigator.pop(context),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
