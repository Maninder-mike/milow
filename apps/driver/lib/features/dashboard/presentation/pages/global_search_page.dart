import 'package:flutter/material.dart';

import 'package:milow_core/milow_core.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:intl/intl.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String _selectedCategory = 'All';

  // All data for searching
  List<Trip> _allTrips = [];
  List<FuelEntry> _allFuelEntries = [];
  bool _isLoading = true;

  final List<String> _categories = ['All', 'Trips', 'Fuel', 'Locations'];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final trips = await TripService.getTrips();
      final fuelEntries = await FuelService.getFuelEntries();

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

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search trips
    if (_selectedCategory == 'All' ||
        _selectedCategory == 'Trips' ||
        _selectedCategory == 'Locations') {
      for (final trip in _allTrips) {
        bool matches = false;
        String matchReason = '';

        // Search by trip number
        if (trip.tripNumber.toLowerCase().contains(lowerQuery)) {
          matches = true;
          matchReason = 'Trip #${trip.tripNumber}';
        }

        // Search by pickup locations
        for (final pickup in trip.pickupLocations) {
          if (pickup.toLowerCase().contains(lowerQuery)) {
            matches = true;
            matchReason = 'Pickup: ${_extractCityState(pickup)}';
            break;
          }
        }

        // Search by delivery locations
        for (final delivery in trip.deliveryLocations) {
          if (delivery.toLowerCase().contains(lowerQuery)) {
            matches = true;
            matchReason = 'Delivery: ${_extractCityState(delivery)}';
            break;
          }
        }

        // Search by notes
        if (trip.notes?.toLowerCase().contains(lowerQuery) == true) {
          matches = true;
          matchReason = 'Notes match';
        }

        if (matches &&
            (_selectedCategory != 'Locations' ||
                matchReason.contains('Pickup') ||
                matchReason.contains('Delivery'))) {
          final route =
              trip.pickupLocations.isNotEmpty &&
                  trip.deliveryLocations.isNotEmpty
              ? '${_extractCityState(trip.pickupLocations.first)} → ${_extractCityState(trip.deliveryLocations.last)}'
              : 'No route';

          results.add(
            SearchResult(
              type: SearchResultType.trip,
              title: 'Trip #${trip.tripNumber}',
              subtitle: route,
              matchReason: matchReason,
              date: trip.tripDate,
              data: trip,
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF3B82F6),
            ),
          );
        }
      }
    }

    // Search fuel entries
    if (_selectedCategory == 'All' ||
        _selectedCategory == 'Fuel' ||
        _selectedCategory == 'Locations') {
      for (final fuel in _allFuelEntries) {
        bool matches = false;
        String matchReason = '';

        // Search by location
        if (fuel.location?.toLowerCase().contains(lowerQuery) == true) {
          matches = true;
          matchReason = 'Location match';
        }

        // Search by truck/reefer number
        if (fuel.truckNumber?.toLowerCase().contains(lowerQuery) == true) {
          matches = true;
          matchReason = 'Truck #${fuel.truckNumber}';
        }
        if (fuel.reeferNumber?.toLowerCase().contains(lowerQuery) == true) {
          matches = true;
          matchReason = 'Reefer #${fuel.reeferNumber}';
        }

        if (matches &&
            (_selectedCategory != 'Locations' ||
                fuel.location?.toLowerCase().contains(lowerQuery) == true)) {
          final location = fuel.location != null
              ? _extractCityState(fuel.location!)
              : 'Unknown location';
          final identifier = fuel.isTruckFuel
              ? fuel.truckNumber ?? 'Truck'
              : fuel.reeferNumber ?? 'Reefer';

          results.add(
            SearchResult(
              type: SearchResultType.fuel,
              title: '${fuel.isTruckFuel ? "Truck" : "Reefer"} - $identifier',
              subtitle:
                  '$location • ${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
              matchReason: matchReason,
              date: fuel.fuelDate,
              data: fuel,
              icon: Icons.local_gas_station_outlined,
              iconColor: const Color(0xFFF59E0B),
            ),
          );
        }
      }
    }

    // Sort by date descending
    results.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
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

  void _openResult(SearchResult result) {
    // Add to recent searches
    final query = _searchController.text.trim();
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 5) {
          _recentSearches = _recentSearches.sublist(0, 5);
        }
      });
    }

    // Navigate to the detail page
    if (result.type == SearchResultType.trip) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEntryPage(editingTrip: result.data as Trip),
        ),
      );
    } else if (result.type == SearchResultType.fuel) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEntryPage(
            editingFuel: result.data as FuelEntry,
            initialTab: 1,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      // Search field
                      Expanded(
                        child: SearchBar(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _performSearch,
                          hintText: 'Search trips, fuel, locations...',
                          leading: const Icon(Icons.search),
                          trailing: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                                icon: const Icon(Icons.close),
                              ),
                          ],
                          elevation: WidgetStateProperty.all(0),
                          backgroundColor: WidgetStateProperty.all(
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _performSearch(_searchController.text);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.isEmpty
                  ? _buildEmptyState(context)
                  : _searchResults.isEmpty
                  ? _buildNoResultsState(context)
                  : _buildResultsList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return ActionChip(
                  onPressed: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(search),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Search suggestions
          Text(
            'Try searching for',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSuggestionItem(
            context,
            Icons.local_shipping_outlined,
            Theme.of(context).colorScheme.primary,
            'Trip numbers',
            'e.g., "1234", "Trip 5678"',
          ),
          const SizedBox(height: 10),
          _buildSuggestionItem(
            context,
            Icons.location_on_outlined,
            Theme.of(context).colorScheme.tertiary,
            'City or state names',
            'e.g., "Chicago", "Texas", "CA"',
          ),
          const SizedBox(height: 10),
          _buildSuggestionItem(
            context,
            Icons.local_gas_station_outlined,
            Theme.of(context).colorScheme.secondary,
            'Truck or reefer numbers',
            'e.g., "TRK-123", "RF-456"',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    IconData icon,
    Color iconColor,
    String title,
    String example,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          _searchController.text = title;
          _performSearch(title);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      example,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    // Group results by type
    final tripResults = _searchResults
        .where((r) => r.type == SearchResultType.trip)
        .toList();
    final fuelResults = _searchResults
        .where((r) => r.type == SearchResultType.fuel)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'} found',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Trip results
        if (tripResults.isNotEmpty) ...[
          _buildResultSection(
            context,
            'Trips',
            Icons.local_shipping_outlined,
            Theme.of(context).colorScheme.primary,
            tripResults,
          ),
          const SizedBox(height: 20),
        ],

        // Fuel results
        if (fuelResults.isNotEmpty) ...[
          _buildResultSection(
            context,
            'Fuel Entries',
            Icons.local_gas_station_outlined,
            Theme.of(context).colorScheme.secondary,
            fuelResults,
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<SearchResult> results,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Badge(label: Text('${results.length}'), backgroundColor: color),
          ],
        ),
        const SizedBox(height: 12),
        ...results.map((result) => _buildResultItem(context, result)),
      ],
    );
  }

  Widget _buildResultItem(BuildContext context, SearchResult result) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () => _openResult(result),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: result.iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(result.icon, color: result.iconColor, size: 24),
        ),
        title: Text(
          result.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result.matchReason,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat.yMMMd().format(result.date),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

enum SearchResultType { trip, fuel }

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String matchReason;
  final DateTime date;
  final dynamic data;
  final IconData icon;
  final Color iconColor;

  SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.matchReason,
    required this.date,
    required this.data,
    required this.icon,
    required this.iconColor,
  });
}
