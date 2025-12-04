import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
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

  String _extractCityState(String address) {
    if (address.isEmpty) return address;

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

    final parts = address.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }

    return address.length > 30 ? '${address.substring(0, 27)}...' : address;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFD0D5DD);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back,
                            color: textColor,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search field
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            onChanged: _performSearch,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search trips, fuel, locations...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                color: secondaryTextColor,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: secondaryTextColor,
                                size: 22,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        _performSearch('');
                                      },
                                      child: Icon(
                                        Icons.close,
                                        color: secondaryTextColor,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _performSearch(_searchController.text);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(color: borderColor),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : secondaryTextColor,
                                ),
                              ),
                            ),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF007AFF),
                      ),
                    )
                  : _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF007AFF),
                      ),
                    )
                  : _searchController.text.isEmpty
                  ? _buildEmptyState(
                      textColor,
                      secondaryTextColor,
                      cardColor,
                      borderColor,
                    )
                  : _searchResults.isEmpty
                  ? _buildNoResultsState(textColor, secondaryTextColor)
                  : _buildResultsList(
                      textColor,
                      secondaryTextColor,
                      cardColor,
                      borderColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          search,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Search suggestions
          Text(
            'Try searching for',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionItem(
            Icons.local_shipping_outlined,
            const Color(0xFF3B82F6),
            'Trip numbers',
            'e.g., "1234", "Trip 5678"',
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
          const SizedBox(height: 10),
          _buildSuggestionItem(
            Icons.location_on_outlined,
            const Color(0xFF10B981),
            'City or state names',
            'e.g., "Chicago", "Texas", "CA"',
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
          const SizedBox(height: 10),
          _buildSuggestionItem(
            Icons.local_gas_station_outlined,
            const Color(0xFFF59E0B),
            'Truck or reefer numbers',
            'e.g., "TRK-123", "RF-456"',
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    IconData icon,
    Color iconColor,
    String title,
    String example,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  example,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(Color textColor, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: secondaryTextColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: GoogleFonts.inter(fontSize: 14, color: secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
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
            style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
          ),
        ),

        // Trip results
        if (tripResults.isNotEmpty) ...[
          _buildResultSection(
            'Trips',
            Icons.local_shipping_outlined,
            const Color(0xFF3B82F6),
            tripResults,
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
          const SizedBox(height: 20),
        ],

        // Fuel results
        if (fuelResults.isNotEmpty) ...[
          _buildResultSection(
            'Fuel Entries',
            Icons.local_gas_station_outlined,
            const Color(0xFFF59E0B),
            fuelResults,
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection(
    String title,
    IconData icon,
    Color color,
    List<SearchResult> results,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
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
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${results.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...results.map(
          (result) => _buildResultItem(
            result,
            textColor,
            secondaryTextColor,
            cardColor,
            borderColor,
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    SearchResult result,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    return GestureDetector(
      onTap: () => _openResult(result),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: result.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(result.icon, color: result.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(result.date),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.matchReason,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
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
