import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
// Tab shell provides nav; this page returns content only
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/features/explore/presentation/pages/visited_states_map_page.dart';
import 'package:milow/features/explore/presentation/widgets/explore_map_view.dart';
import 'package:milow/features/explore/presentation/utils/explore_map_helper.dart';
import 'package:milow/features/explore/presentation/widgets/stats_overview_card.dart';
import 'package:milow/features/explore/presentation/widgets/state_collector_card.dart';
import 'package:milow/features/explore/presentation/widgets/smart_suggestions_card.dart';

import 'package:milow/core/services/geo_service.dart';

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
  final String _selectedCategory = 'All Routes';

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

  List<ExploreMapMarker> _mapMarkers = [];
  bool _isMapLoading = true;

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

      // Generate map markers in background
      await _generateMapMarkers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const Set<String> _usStateCodes = {
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'DC',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  };

  Set<String> _visitedStates = {};

  Future<void> _generateMapMarkers() async {
    final markers = <ExploreMapMarker>[];
    final states = <String>{};
    // GeoService is static, no instance needed

    // Process all trips
    // final recentTrips = _allTrips.take(10).toList(); // OLD: limit 10
    final trips = _allTrips; // NEW: use all
    for (final trip in trips) {
      if (trip.deliveryLocations.isNotEmpty) {
        final loc =
            trip.deliveryLocations.last; // Use last delivery as main point

        // Extract state for collector
        final mainLoc = _extractCityState(
          loc,
        ); // Normalize address for better geocoding success
        final state = _extractStateCode(loc);
        if (state != null && _usStateCodes.contains(state)) states.add(state);

        final latLng = await GeoService.getCoordinates(mainLoc);
        if (latLng != null) {
          markers.add(
            ExploreMapMarker(
              id: trip.id ?? 'trip_${DateTime.now().millisecondsSinceEpoch}',
              type: MapMarkerType.trip,
              point: latLng,
              title: 'Trip ${trip.tripNumber}',
              subtitle: mainLoc,
              date: trip.createdAt ?? DateTime.now(),
              data: trip,
            ),
          );
        }
      }
    }

    // Process all fuel
    // final recentFuel = _allFuelEntries.take(10).toList(); // OLD: limit 10
    final fuelList = _allFuelEntries; // NEW: use all
    for (final fuel in fuelList) {
      if (fuel.location != null) {
        // Extract state for collector
        final mainLoc = _extractCityState(fuel.location!);
        final state = _extractStateCode(fuel.location!);
        if (state != null && _usStateCodes.contains(state)) states.add(state);

        final latLng = await GeoService.getCoordinates(mainLoc);
        if (latLng != null) {
          markers.add(
            ExploreMapMarker(
              id: fuel.id ?? 'fuel_${DateTime.now().millisecondsSinceEpoch}',
              type: MapMarkerType.fuel,
              point: latLng,
              title: fuel.isTruckFuel ? 'Truck Fuel' : 'Reefer Fuel',
              subtitle:
                  '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel} @ $mainLoc',
              date: fuel.createdAt ?? DateTime.now(),
              data: fuel,
            ),
          );
        }
      }
    }

    // Also scan all trips for states, not just the recent ones for markers
    for (final trip in _allTrips) {
      for (final loc in trip.deliveryLocations) {
        final state = _extractStateCode(loc);
        if (state != null && _usStateCodes.contains(state)) states.add(state);
      }
    }

    if (mounted) {
      setState(() {
        _mapMarkers = markers;
        _isMapLoading = false;
        _visitedStates = states;
      });
      _calculateStats();
    }
  }

  double _statsTotalMiles = 0;
  double _statsFuelCost = 0;
  int _statsTripCount = 0;

  void _calculateStats() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Filter trips for this month
    final monthTrips = _allTrips
        .where((t) => t.tripDate.isAfter(startOfMonth))
        .toList();

    double miles = 0;
    for (var trip in monthTrips) {
      miles += trip.totalDistance ?? 0;
    }

    // Filter fuel for this month
    final monthFuel = _allFuelEntries
        .where((f) => f.fuelDate.isAfter(startOfMonth))
        .toList();
    double cost = 0;
    for (var fuel in monthFuel) {
      cost += fuel.totalCost;
    }

    if (mounted) {
      setState(() {
        _statsTotalMiles = miles;
        _statsTripCount = monthTrips.length;
        _statsFuelCost = cost;
      });
    }
  }

  String? _extractStateCode(String address) {
    if (address.isEmpty) return null;

    // Normalize
    final normalized = address.replaceAll('\n', ', ').toUpperCase();

    // Pattern for "City, ST" or "City, ST ZIP"
    final statePattern = RegExp(r',\s*([A-Z]{2})(?:\s+[A-Z0-9\s-]+)?(?:,|$)');
    final match = statePattern.firstMatch(normalized);
    if (match != null) {
      return match.group(1);
    }

    // Pattern for "City ST ZIP" (no comma)
    final zipPattern = RegExp(r'\s+([A-Z]{2})\s+\d{5}');
    final zipMatch = zipPattern.firstMatch(normalized);
    if (zipMatch != null) {
      return zipMatch.group(1);
    }

    // Basic fallback: Check last part if it looks like a state code
    final parts = normalized.split(RegExp(r'[\s,]+'));
    if (parts.isNotEmpty) {
      // iterate backwards
      for (var i = parts.length - 1; i >= 0; i--) {
        final part = parts[i];
        if (part.length == 2 && RegExp(r'^[A-Z]{2}$').hasMatch(part)) {
          // Exclude common non-state 2-letter words like "RD", "ST", "DR"?
          // Actually US state codes are specific.
          // For now, assume it's a state if it's near the end.
          return part;
        }
      }
    }

    return null;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 60,
          strokeWidth: 3.0,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                floating: true,
                snap: true,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: () => context.go('/dashboard'),
                ),
                title: Text(
                  AppLocalizations.of(context)?.explore ?? 'Explore',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Interactive Map Preview

                            // Interactive Map Preview
                            if (_selectedCategory == 'All Routes' ||
                                _selectedCategory == 'Long Haul' ||
                                _selectedCategory == 'Regional' ||
                                _selectedCategory == 'Local') ...[
                              const _SectionHeaderRow(title: 'Activity Map'),
                              const SizedBox(height: 12),
                              if (_isMapLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                ExploreMapView(
                                  markers: _mapMarkers,
                                  onMarkerTap: (marker) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(marker.title),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(marker.subtitle),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Date: ${DateFormat.yMMMd().format(marker.date)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 24),
                              StateCollectorCard(
                                visitedStates: _visitedStates,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VisitedStatesMapPage(
                                        trips: _allTrips,
                                        fuelEntries: _allFuelEntries,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Personal Stats & Insights
                              StatsOverviewCard(
                                totalMiles: _statsTotalMiles,
                                totalFuelCost: _statsFuelCost,
                                tripCount: _statsTripCount,
                              ),
                              const SizedBox(height: 24),

                              SmartSuggestionsCard(
                                trips: _allTrips,
                                fuelEntries: _allFuelEntries,
                              ),
                              const SizedBox(height: 24),
                            ],

                            _SectionHeaderRow(
                              title: AppLocalizations.of(
                                context,
                              )!.popularDestinations,
                              onAction: _filteredDestinations.isNotEmpty
                                  ? () => _navigateToAllDestinations()
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _buildDestinationsList(),
                            const SizedBox(height: 24),
                            _SectionHeaderRow(
                              title: AppLocalizations.of(
                                context,
                              )!.recentActivity,
                              onAction: _filteredActivity.isNotEmpty
                                  ? () => _navigateToAllActivity()
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _buildActivityList(),
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

  Widget _buildDestinationsList() {
    if (_filteredDestinations.isEmpty) {
      return const _EmptyStateCard(
        message: 'No recent destinations found.',
        icon: Icons.map,
      );
    }
    return Column(
      children: _filteredDestinations.take(5).map((dest) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SimpleDestinationCard(destination: dest),
        );
      }).toList(),
    );
  }

  Widget _buildActivityList() {
    if (_filteredActivity.isEmpty) {
      return const _EmptyStateCard(
        message: 'No recent activity.',
        icon: Icons.history,
      );
    }
    return Column(
      children: _filteredActivity.take(5).map((activity) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SimpleActivityCard(activity: activity),
        );
      }).toList(),
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

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  const _SectionHeaderRow({required this.title, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              'See all',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
    return Card(
      elevation: 0, // Flat M3 style
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Standard 20px
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

class _SimpleDestinationCard extends StatelessWidget {
  final Map<String, dynamic> destination;

  const _SimpleDestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    final city = destination['city'] as String;
    final description = destination['description'] as String;

    return _GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_city,
              color: Colors.orange,
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return DateFormat('MMM d').format(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = activity['title'] as String;
    final subtitle = activity['subtitle'] as String;
    final date = activity['date'] as DateTime;
    final icon = activity['icon'] as IconData;

    return _GlassyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(date),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Color _getDistanceColor(BuildContext context, double? distance) {
    if (distance == null) return Theme.of(context).colorScheme.outline;
    if (distance > 500) return Theme.of(context).colorScheme.primary;
    if (distance >= 200) return Colors.orange;
    return Theme.of(context).colorScheme.tertiary;
  }

  String _getDistanceCategory(double? distance) {
    if (distance == null) return '';
    if (distance > 500) return 'Long Haul';
    if (distance >= 200) return 'Regional';
    return 'Local';
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final route =
        trip.pickupLocations.isNotEmpty && trip.deliveryLocations.isNotEmpty
        ? '${widget.extractCityState(trip.pickupLocations.first)} → ${widget.extractCityState(trip.deliveryLocations.last)}'
        : 'No route';
    final distance = trip.totalDistance;
    final distanceColor = _getDistanceColor(context, distance);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                          distance != null ? distance.toStringAsFixed(0) : '--',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip.distanceUnitLabel.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: distanceColor,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 16),
                  // Trip info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip ${trip.tripNumber}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(context),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final trip = widget.trip;
    final distance = trip.totalDistance;
    final category = _getDistanceCategory(distance);
    final distanceColor = _getDistanceColor(context, distance);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Trip details section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trip Details',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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
                          color: distanceColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: distanceColor,
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
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _formatDate(trip.tripDate),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        context,
                        icon: Icons.directions_car_outlined,
                        label: 'Truck',
                        value: trip.truckNumber,
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
                color: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Odometer',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${trip.startOdometer?.toStringAsFixed(0) ?? '--'} → ${trip.endOdometer?.toStringAsFixed(0) ?? '--'} ${trip.distanceUnitLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  context,
                  icon: Icons.trip_origin,
                  label: 'Pickups',
                  locations: trip.pickupLocations,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationChip(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'Deliveries',
                  locations: trip.deliveryLocations,
                  color: Colors.orange,
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rv_hookup,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      trip.trailers.join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
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
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
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

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
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
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
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
    final city = widget.destination['city'] as String;
    final count = widget.destination['count'] as int;
    final trips = widget.destination['trips'] as List<Trip>? ?? [];
    final totalMiles = widget.destination['totalMiles'] as double? ?? 0.0;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                        ),
                        Text(
                          count == 1 ? 'TRIP' : 'TRIPS',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 9,
                                letterSpacing: 0.5,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (totalMiles > 0)
                          Text(
                            '${totalMiles.toStringAsFixed(0)} miles total',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(
                context,
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
    );
  }

  Widget _buildExpandedContent(
    BuildContext context, {
    required List<Trip> trips,
    required double totalMiles,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.local_shipping_outlined,
                  label: trips.length == 1 ? 'Trip' : 'Trips',
                  value: '${trips.length}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.straighten_outlined,
                  label: 'Distance',
                  value: '${totalMiles.toStringAsFixed(0)} mi',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),

          if (trips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Trips',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip ${trip.tripNumber}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            route,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (trip.totalDistance != null)
                          Text(
                            '${trip.totalDistance!.toStringAsFixed(0)} mi',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    final isTrip = widget.activity['type'] == 'trip';
    final accentColor = isTrip
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;
    final date = widget.activity['date'] as DateTime;
    final icon = widget.activity['icon'] as IconData;
    final title = widget.activity['title'] as String;
    final subtitle = widget.activity['subtitle'] as String;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  ? _buildTripExpandedContent(context)
                  : _buildFuelExpandedContent(context),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripExpandedContent(BuildContext context) {
    final trip = widget.activity['trip'] as Trip?;
    if (trip == null) return const SizedBox.shrink();

    final distance = trip.totalDistance;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Trip overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatDate(trip.tripDate),
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.directions_car_outlined,
                  label: 'Truck',
                  value: trip.truckNumber,
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
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
                  context,
                  icon: Icons.trip_origin,
                  label: 'From',
                  locations: trip.pickupLocations,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationInfo(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'To',
                  locations: trip.deliveryLocations,
                  color: Colors.orange,
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rv_hookup,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trailers: ${trip.trailers.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
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
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
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

  Widget _buildFuelExpandedContent(BuildContext context) {
    final fuel = widget.activity['fuel'] as FuelEntry?;
    if (fuel == null) return const SizedBox.shrink();

    final accentColor = Theme.of(context).colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Fuel overview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatDate(fuel.fuelDate),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiary,
                    ),
                  ),
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
                  context,
                  icon: Icons.local_gas_station_outlined,
                  label: 'Quantity',
                  value:
                      '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFuelDetailCard(
                  context,
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: fuel.formattedPricePerUnit,
                  color: Theme.of(context).colorScheme.tertiary,
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
                    context,
                    icon: Icons.local_shipping_outlined,
                    label: 'Truck',
                    value: fuel.truckNumber!,
                    color: Colors.orange,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferNumber != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.ac_unit_outlined,
                    label: 'Reefer',
                    value: fuel.reeferNumber!,
                    color: Colors.blue,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              if (fuel.isTruckFuel && fuel.odometerReading != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.speed_outlined,
                    label: 'Odometer',
                    value:
                        '${fuel.odometerReading!.toStringAsFixed(0)} ${fuel.distanceUnitLabel}',
                    color: Colors.purple,
                  ),
                )
              else if (fuel.isReeferFuel && fuel.reeferHours != null)
                Expanded(
                  child: _buildFuelDetailCard(
                    context,
                    icon: Icons.timer_outlined,
                    label: 'Hours',
                    value: fuel.reeferHours!.toStringAsFixed(1),
                    color: Theme.of(context).colorScheme.secondary,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fuel.location!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
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

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> locations,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
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
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          if (locations.length > 2)
            Text(
              '+${locations.length - 2} more',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelDetailCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryLabel == 'All Routes'
              ? 'Popular Destinations'
              : '$categoryLabel Destinations',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: destinations.isEmpty
          ? Center(
              child: Text(
                categoryLabel == 'All Routes'
                    ? 'No destinations found'
                    : 'No destinations for $categoryLabel trips',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete $title?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryLabel == 'All Routes'
              ? 'All Activity'
              : '${widget.categoryLabel} Activity',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: _activity.isEmpty
          ? Center(
              child: Text(
                widget.categoryLabel == 'All Routes'
                    ? 'No activity found'
                    : 'No ${widget.categoryLabel} activity found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Modify',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Delete',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onError,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.onError,
                        ),
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
