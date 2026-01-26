import 'dart:async';
import 'package:flutter/material.dart';
import 'package:milow/core/utils/address_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart';
import 'package:milow_core/milow_core.dart';

import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/features/dashboard/presentation/widgets/records_export_sheet.dart';

class RecordsListPage extends StatefulWidget {
  const RecordsListPage({super.key});

  @override
  State<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends State<RecordsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _isSearching = false; // Add search state
  DateTimeRange? _selectedDateRange;

  // Real data from Supabase
  List<Map<String, dynamic>> _allRecords = [];
  bool _isLoading = true;

  // Track expanded cards
  final Set<String> _expandedCards = {};

  // PDF Export Column Selection
  static const Map<String, String> tripColumnLabels = {
    'tripNumber': 'Trip #',
    'date': 'Date',
    'truck': 'Truck',
    'trailer': 'Trailer',
    'borderCrossing': 'Border Crossing',
    'from': 'From (Pickup)',
    'to': 'To (Delivery)',
    'miles': 'Miles/Km',
    'notes': 'Notes',
    'officialUse': 'Official Use',
  };

  static const Map<String, String> fuelColumnLabels = {
    'date': 'Date',
    'type': 'Type',
    'truck': 'Truck #',
    'location': 'Location',
    'quantity': 'Quantity',
    'odometer': 'Odometer',
    'cost': 'Cost',
  };

  // Default selected columns (List for maintaining order)
  final List<String> _selectedTripColumns = [
    'tripNumber',
    'date',
    'from',
    'borderCrossing',
    'to',
    'notes',
    'officialUse',
  ];

  final List<String> _selectedFuelColumns = [
    'date',
    'type',
    'truck',
    'location',
    'odometer',
    'quantity',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadColumnPreferences();
  }

  Future<void> _loadColumnPreferences() async {
    final savedTripCols = await PreferencesService.getTripColumns();
    final savedFuelCols = await PreferencesService.getFuelColumns();

    if (savedTripCols.isNotEmpty) {
      setState(() {
        _selectedTripColumns.clear();
        _selectedTripColumns.addAll(savedTripCols);
      });
    }

    if (savedFuelCols.isNotEmpty) {
      setState(() {
        _selectedFuelColumns.clear();
        _selectedFuelColumns.addAll(savedFuelCols);
      });
    }
  }

  Future<void> _saveColumnPreferences() async {
    await PreferencesService.setTripColumns(_selectedTripColumns);
    await PreferencesService.setFuelColumns(_selectedFuelColumns);
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    DataPrefetchService.instance.invalidateCache();
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final trips = await TripRepository.getTrips();
      final fuelEntries = await FuelRepository.getFuelEntries();

      final List<Map<String, dynamic>> combined = [];

      for (final trip in trips) {
        final pickups = trip.pickupLocations;
        final deliveries = trip.deliveryLocations;
        final route = pickups.isNotEmpty && deliveries.isNotEmpty
            ? '${AddressUtils.extractCityState(pickups.first)} → ${AddressUtils.extractCityState(deliveries.last)}'
            : 'No route';
        final distance = trip.totalDistance;
        final distanceStr = distance != null
            ? '${distance.toStringAsFixed(0)} ${trip.distanceUnitLabel}'
            : '-';

        combined.add({
          'id': 'Trip #${trip.tripNumber}',
          'type': 'trip',
          'description': route,
          'date': DateFormat('MMM d, yyyy').format(trip.tripDate),
          'value': distanceStr,
          'rawDate': trip.tripDate,
          'rawDistance': distance ?? 0,
          'data': trip,
        });
      }

      for (final fuel in fuelEntries) {
        final location = fuel.location != null
            ? AddressUtils.extractCityState(fuel.location!)
            : 'Unknown location';
        final quantity =
            '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}';
        final identifier = fuel.isTruckFuel
            ? fuel.truckNumber ?? 'Truck'
            : fuel.reeferNumber ?? 'Reefer';

        combined.add({
          'id': '${fuel.isTruckFuel ? "Truck" : "Reefer"} - $identifier',
          'type': 'fuel',
          'description': location,
          'date': DateFormat('MMM d, yyyy').format(fuel.fuelDate),
          'value': quantity,
          'rawDate': fuel.fuelDate,
          'rawQuantity': fuel.fuelQuantity,
          'data': fuel,
        });
      }

      // Sort by date descending
      combined.sort(
        (a, b) =>
            (b['rawDate'] as DateTime).compareTo(a['rawDate'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _allRecords = combined;
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

  List<Map<String, dynamic>> get _filteredRecords {
    return _allRecords.where((record) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (record['id'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (record['description'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Parse value for distance-based filtering (trips only)
      bool matchesFilter = true;
      if (_selectedFilter != 'All') {
        if (record['type'] == 'trip') {
          final distance = (record['rawDistance'] as num?)?.toDouble() ?? 0;
          matchesFilter =
              (_selectedFilter == 'Short (<100 mi)' && distance < 100) ||
              (_selectedFilter == 'Medium (100-200 mi)' &&
                  distance >= 100 &&
                  distance <= 200) ||
              (_selectedFilter == 'Long (>200 mi)' && distance > 200) ||
              (_selectedFilter == 'Trips Only');
        } else if (record['type'] == 'fuel') {
          matchesFilter = _selectedFilter == 'Fuel Only';
        }
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  /// Get records for export with specific filter and date range
  List<Map<String, dynamic>> _getExportRecords(
    String filter,
    DateTimeRange? dateRange,
  ) {
    return _allRecords.where((record) {
      // Filter by type
      bool matchesFilter = true;
      if (filter != 'All') {
        if (record['type'] == 'trip') {
          final distance = (record['rawDistance'] as num?)?.toDouble() ?? 0;
          matchesFilter =
              (filter == 'Short (<100 mi)' && distance < 100) ||
              (filter == 'Medium (100-200 mi)' &&
                  distance >= 100 &&
                  distance <= 200) ||
              (filter == 'Long (>200 mi)' && distance > 200) ||
              (filter == 'Trips Only');
        } else if (record['type'] == 'fuel') {
          matchesFilter = filter == 'Fuel Only';
        }
      }

      // Filter by date range
      bool matchesDate = true;
      if (dateRange != null) {
        final recordDate = record['rawDate'] as DateTime?;
        if (recordDate != null) {
          final startOfDay = DateTime(
            dateRange.start.year,
            dateRange.start.month,
            dateRange.start.day,
          );
          final endOfDay = DateTime(
            dateRange.end.year,
            dateRange.end.month,
            dateRange.end.day,
            23,
            59,
            59,
          );
          matchesDate =
              recordDate.isAfter(
                startOfDay.subtract(const Duration(seconds: 1)),
              ) &&
              recordDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
        }
      }

      return matchesFilter && matchesDate;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textColor = tokens.textPrimary;
    final secondaryTextColor = tokens.textSecondary;
    final cardColor = tokens.surfaceContainer;
    final borderColor = tokens.subtleBorderColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Main AppBar with Search Toggle
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              floating: true,
              pinned: true,
              leading: _isSearching
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        hintStyle: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: secondaryTextColor),
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: textColor),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    )
                  : Text(
                      'All Records',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
              actions: [
                if (!_isSearching)
                  IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),

                if (!_isSearching)
                  IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        useSafeArea: true,
                        backgroundColor: Theme.of(
                          context,
                        ).extension<DesignTokens>()!.surfaceContainer,
                        builder: (context) => RecordsExportSheet(
                          initialDateRange: _selectedDateRange,
                          initialFilter: _selectedFilter,
                          initialTripColumns: _selectedTripColumns,
                          initialFuelColumns: _selectedFuelColumns,
                          onDownloadCSV:
                              (
                                dateRange,
                                filter,
                                tripCols,
                                fuelCols,
                                includeSummary,
                              ) {
                                setState(() {
                                  _selectedDateRange = dateRange;
                                  _selectedFilter = filter;
                                  _selectedTripColumns
                                    ..clear()
                                    ..addAll(tripCols);
                                  _selectedFuelColumns
                                    ..clear()
                                    ..addAll(fuelCols);
                                });
                                _saveColumnPreferences();
                                _downloadCSV(filter, dateRange);
                              },
                          onDownloadPDF:
                              (
                                dateRange,
                                filter,
                                tripCols,
                                fuelCols,
                                includeSummary,
                              ) {
                                setState(() {
                                  _selectedDateRange = dateRange;
                                  _selectedFilter = filter;
                                  _selectedTripColumns
                                    ..clear()
                                    ..addAll(tripCols);
                                  _selectedFuelColumns
                                    ..clear()
                                    ..addAll(fuelCols);
                                });
                                _saveColumnPreferences();
                                _downloadPDF(
                                  filter,
                                  dateRange,
                                  includeSummaryBanner: includeSummary,
                                );
                              },
                          onSavePreferences: (tripCols, fuelCols) {
                            setState(() {
                              _selectedTripColumns
                                ..clear()
                                ..addAll(tripCols);
                              _selectedFuelColumns
                                ..clear()
                                ..addAll(fuelCols);
                            });
                            _saveColumnPreferences();
                          },
                        ),
                      );
                    },
                  ),

                if (_isSearching && _searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
            ),

            // Filter Bar (Now separate SliverToBoxAdapter)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48, // Comfort height for touch targets
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Trips Only'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Fuel Only'),
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      width: 1,
                      color: tokens.subtleBorderColor,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    _buildFilterChip('Short (<100 mi)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Medium (100-200 mi)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Long (>200 mi)'),
                  ],
                ),
              ),
            ),
            // Removed extra SizedBox here for tighter layout
          ];
        },
        body: Container(
          color: Colors.transparent,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 60,
            strokeWidth: 3.0,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 3.0),
                  )
                : _filteredRecords.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_off_rounded,
                                size: 64,
                                color: secondaryTextColor.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matching records',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Try selecting a different filter',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: secondaryTextColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      context.tokens.spacingM,
                      0,
                      context.tokens.spacingM,
                      context.tokens.spacingL, // Reduced bottom padding
                    ),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      // Add spacing between items - Reduced to spacingXS (4) or spacingS (8)
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: context.tokens.spacingS,
                        ),
                        child: Dismissible(
                          key: Key('${record['type']}_${record['id']}'),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                tokens.shapeM,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Modify',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            decoration: BoxDecoration(
                              color: tokens.error,
                              borderRadius: BorderRadius.circular(
                                tokens.shapeM,
                              ),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Delete',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              // Capture scaffold messenger before async gap
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );

                              // Delete action - show beautiful confirmation dialog
                              final confirmed = await showModalBottomSheet<bool>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (dialogContext) {
                                  final tokens = dialogContext.tokens;
                                  final dialogTextColor = tokens.textPrimary;
                                  final dialogSecondaryColor =
                                      tokens.textSecondary;

                                  return Container(
                                    margin: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceContainer,
                                      borderRadius: BorderRadius.circular(
                                        tokens.shapeXL,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, -5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 12),
                                        // Handle bar
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: dialogSecondaryColor
                                                .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // Warning icon
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: tokens.error.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: tokens.error,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        // Title
                                        Text(
                                          'Delete Record',
                                          style: Theme.of(dialogContext)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: dialogTextColor,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Message
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                          child: Text(
                                            'Are you sure you want to delete ${record['id']}? This action cannot be undone.',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(dialogContext)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: dialogSecondaryColor,
                                                  height: 1.5,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        // Buttons
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              // Cancel button
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(dialogContext)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            tokens.shapeM,
                                                          ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Cancel',
                                                        style:
                                                            Theme.of(
                                                                  dialogContext,
                                                                )
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      dialogTextColor,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Delete button
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: tokens.error,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            tokens.shapeM,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: tokens.error
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Delete',
                                                        style:
                                                            Theme.of(
                                                                  dialogContext,
                                                                )
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
                                  );
                                },
                              );

                              if (confirmed == true) {
                                // Delete from Supabase
                                try {
                                  final isTrip = record['type'] == 'trip';
                                  final data = record['data'];

                                  if (isTrip) {
                                    final trip = data as Trip;
                                    if (trip.id != null) {
                                      await TripRepository.deleteTrip(trip.id!);
                                    }
                                  } else {
                                    final fuel = data as FuelEntry;
                                    if (fuel.id != null) {
                                      await FuelRepository.deleteFuelEntry(
                                        fuel.id!,
                                      );
                                    }
                                  }

                                  // Remove from local list
                                  setState(() {
                                    _allRecords.removeWhere(
                                      (r) =>
                                          r['type'] == record['type'] &&
                                          r['id'] == record['id'],
                                    );
                                  });

                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('${record['id']} deleted'),
                                      backgroundColor: tokens.success,
                                    ),
                                  );
                                  return false; // Don't auto-dismiss, we already removed it
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: tokens.error,
                                    ),
                                  );
                                  return false;
                                }
                              }
                              return false;
                            } else {
                              // Modify action - show bottom sheet
                              _showModifyBottomSheet(
                                record,
                                textColor,
                                secondaryTextColor,
                                cardColor,
                                borderColor,
                              );
                              return false;
                            }
                          },
                          child: _buildExpandableCard(
                            record,
                            cardColor,
                            borderColor,
                            textColor,
                            secondaryTextColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
      // Styling to match M3 aesthetics
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontSize: 13, // Slightly smaller
      ),
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surfaceContainerLow,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : context.tokens.subtleBorderColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.tokens.shapeFull),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      showCheckmark: false, // Cleaner look without checkmark
    );
  }

  Widget _buildExpandableCard(
    Map<String, dynamic> record,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final tokens = context.tokens;
    final cardKey = '${record['type']}_${record['id']}';
    final isExpanded = _expandedCards.contains(cardKey);
    final isTrip = record['type'] == 'trip';
    final data = record['data'];

    // Premium Design Logic
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final tertiaryColor = theme.colorScheme.tertiary;

    final iconColor = isTrip ? primaryColor : tertiaryColor;
    final containerColor = theme.colorScheme.surfaceContainerLow;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedCards.remove(cardKey);
          } else {
            _expandedCards.add(cardKey);
          }
        });
      },
      child: AnimatedContainer(
        duration: M3ExpressiveMotion.durationMedium,
        curve: M3ExpressiveMotion.standard,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(
            tokens.shapeM,
          ), // Reduced radius slightly
          // Remove border, use subtle shadow for expanded state or flat for collapsed
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          // Subtle border for definition
          border: Border.all(
            color: isExpanded
                ? primaryColor.withValues(alpha: 0.3)
                : borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias, // Ensure child inkwells don't bleed
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // shrink wrap
          children: [
            // Main card content area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ), // Reduced padding
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center align for cleaner look
                children: [
                  // Leading Icon/Avatar
                  Container(
                    width: 40, // Reduced size
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        tokens.shapeS,
                      ), // Matching radius
                    ),
                    child: Icon(
                      isTrip
                          ? Icons.route_rounded
                          : Icons.local_gas_station_rounded,
                      color: iconColor,
                      size: 20, // Reduced icon
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced spacing
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Header Row (ID and Badge)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                record['id'] as String? ?? '',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 15, // Adjusted size
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Compact Value Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  tokens.shapeXS,
                                ),
                                border: Border.all(
                                  color: borderColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                record['value'] as String? ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: iconColor,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2), // Tighter spacing
                        // Description Row (Description + Date)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                record['description'] as String? ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              record['date'] as String? ?? '',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expanded details
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: borderColor.withValues(alpha: 0.5),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      4,
                    ), // Adjusted padding
                    child: isTrip
                        ? _buildTripDetails(
                            data as Trip,
                            textColor,
                            secondaryTextColor,
                          )
                        : _buildFuelDetails(
                            data as FuelEntry,
                            textColor,
                            secondaryTextColor,
                          ),
                  ),
                  // Collapse handle area - reduced height
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: secondaryTextColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: M3ExpressiveMotion.durationShort,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetails(
    Trip trip,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Truck & Trailers
        _buildDetailRow(
          Icons.local_shipping_outlined,
          'Truck',
          trip.truckNumber,
          textColor,
          secondaryTextColor,
        ),
        if (trip.trailers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.rv_hookup,
            'Trailer${trip.trailers.length > 1 ? 's' : ''}',
            trip.trailers.join(', '),
            textColor,
            secondaryTextColor,
          ),
        ],
        // Odometer readings
        if (trip.startOdometer != null || trip.endOdometer != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.speed,
            'Odometer',
            '${trip.startOdometer?.toStringAsFixed(0) ?? '-'} → ${trip.endOdometer?.toStringAsFixed(0) ?? '-'} ${trip.distanceUnitLabel}',
            textColor,
            secondaryTextColor,
          ),
        ],
        // Pickup locations
        if (trip.pickupLocations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDetailSection(
            Icons.arrow_upward,
            'Pickup${trip.pickupLocations.length > 1 ? 's' : ''}',
            trip.pickupLocations,
            tokens.success,
            textColor,
            secondaryTextColor,
          ),
        ],
        // Delivery locations
        if (trip.deliveryLocations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDetailSection(
            Icons.arrow_downward,
            'Deliver${trip.deliveryLocations.length > 1 ? 'ies' : 'y'}',
            trip.deliveryLocations,
            tokens.error,
            textColor,
            secondaryTextColor,
          ),
        ],
        // Notes
        if (trip.notes != null && trip.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.notes,
            'Notes',
            trip.notes!,
            textColor,
            secondaryTextColor,
          ),
        ],
      ],
    );
  }

  Widget _buildFuelDetails(
    FuelEntry fuel,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fuel Type & Vehicle
        _buildDetailRow(
          fuel.isTruckFuel ? Icons.local_shipping_outlined : Icons.ac_unit,
          fuel.isTruckFuel ? 'Truck' : 'Reefer',
          fuel.isTruckFuel
              ? (fuel.truckNumber ?? '-')
              : (fuel.reeferNumber ?? '-'),
          textColor,
          secondaryTextColor,
        ),
        // Location
        if (fuel.location != null && fuel.location!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.location_on_outlined,
            'Location',
            fuel.location!,
            textColor,
            secondaryTextColor,
          ),
        ],
        // Quantity & Price
        const SizedBox(height: 12),
        _buildDetailRow(
          Icons.local_gas_station,
          'Quantity',
          '${fuel.fuelQuantity.toStringAsFixed(2)} ${fuel.fuelUnitLabel}',
          textColor,
          secondaryTextColor,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          Icons.attach_money,
          'Price',
          fuel.formattedPricePerUnit,
          textColor,
          secondaryTextColor,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          Icons.receipt_long,
          'Total',
          fuel.formattedTotalCost,
          textColor,
          secondaryTextColor,
          valueColor: tokens.success,
        ),
        // Odometer / Reefer Hours
        if (fuel.isTruckFuel && fuel.odometerReading != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.speed,
            'Odometer',
            '${fuel.odometerReading!.toStringAsFixed(0)} ${fuel.distanceUnitLabel}',
            textColor,
            secondaryTextColor,
          ),
        ],
        if (!fuel.isTruckFuel && fuel.reeferHours != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.timer_outlined,
            'Reefer Hours',
            fuel.reeferHours!.toStringAsFixed(1),
            textColor,
            secondaryTextColor,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color secondaryTextColor, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: secondaryTextColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    IconData icon,
    String label,
    List<String> items,
    Color iconColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  void _showModifyBottomSheet(
    Map<String, dynamic> record,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) async {
    final isTrip = record['type'] == 'trip';
    final data = record['data'];

    // Navigate to AddEntryPage with the record data for editing
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryPage(
          editingTrip: isTrip ? data as Trip : null,
          editingFuel: !isTrip ? data as FuelEntry : null,
          initialTab: isTrip ? 0 : 1,
        ),
      ),
    );

    // Refresh records if update was successful
    if (result == true) {
      await _loadRecords();
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _downloadCSV(String filter, DateTimeRange? dateRange) async {
    // Show loading indicator
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 3.0,
          ),
        ),
      ),
    );

    try {
      // Get records to export
      final recordsToExport = _getExportRecords(filter, dateRange);

      // Prepare CSV data
      final List<List<dynamic>> rows = [];

      // Add Header
      rows.add([
        'Date',
        'Type',
        'ID/Truck',
        'Description/Location',
        'Distance/Quantity',
        'Unit',
        'Cost',
        'Notes',
        'From',
        'To',
        'Odometer',
      ]);

      // Add Rows
      for (var record in recordsToExport) {
        final date = DateFormat('yyyy-MM-dd').format(record['rawDate']);
        final type = record['type'] == 'trip' ? 'Trip' : 'Fuel';
        final data = record['data'];

        if (record['type'] == 'trip') {
          final trip = data as Trip;
          final distance = trip.totalDistance?.toStringAsFixed(1) ?? '';
          final unit = trip.distanceUnitLabel;
          final from = trip.pickupLocations.isNotEmpty
              ? AddressUtils.formatForPdf(trip.pickupLocations.first)
              : '';
          final to = trip.deliveryLocations.isNotEmpty
              ? AddressUtils.formatForPdf(trip.deliveryLocations.last)
              : '';

          rows.add([
            date,
            type,
            'Trip #${trip.tripNumber}',
            trip.notes ?? '', // Description used for notes here or route?
            // Actually `record['description']` has route.
            // But let's use specific fields.
            distance,
            unit,
            '', // Cost
            trip.notes ?? '',
            from,
            to,
            '', // Odometer
          ]);
        } else {
          final fuel = data as FuelEntry;
          final quantity = fuel.fuelQuantity.toStringAsFixed(1);
          final unit = fuel.fuelUnitLabel;
          final cost = fuel.totalCost.toStringAsFixed(2);
          final truck = fuel.isTruckFuel
              ? (fuel.truckNumber ?? 'Truck')
              : (fuel.reeferNumber ?? 'Reefer');
          final location = AddressUtils.formatForPdf(fuel.location ?? '');
          final odometer =
              fuel.odometerReading?.toStringAsFixed(0) ??
              (fuel.reeferHours?.toStringAsFixed(1) ?? '');

          rows.add([
            date,
            type,
            truck,
            location,
            quantity,
            unit,
            cost,
            '', // Notes
            '', // From
            '', // To
            odometer,
          ]);
        }
      }

      final csvData = const ListToCsvConverter().convert(rows);

      // Save file
      final fileName =
          'Milow_Records_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final path = '${directory!.path}/$fileName';
      final file = File(path);
      await file.writeAsString(csvData);

      if (mounted) {
        Navigator.pop(context); // Close loading
        _showExportSuccessDialog(path, fileName);
      }
    } catch (e) {
      if (mounted) {
        final tokens = context.tokens;
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generating CSV: $e',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            backgroundColor: tokens.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeS),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF(
    String filter,
    DateTimeRange? dateRange, {
    bool includeSummaryBanner = true,
  }) async {
    // Show loading indicator
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 3.0,
          ),
        ),
      ),
    );

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Get records to export using the proper filter method
      final recordsToExport = _getExportRecords(filter, dateRange);

      // Separate trips and fuel entries, then sort in ascending order by date
      final tripRecords =
          recordsToExport.where((r) => r['type'] == 'trip').toList()
            ..sort((a, b) {
              final dateA = a['rawDate'] as DateTime?;
              final dateB = b['rawDate'] as DateTime?;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateA.compareTo(dateB); // Ascending order
            });

      final fuelRecords =
          recordsToExport.where((r) => r['type'] == 'fuel').toList()
            ..sort((a, b) {
              final dateA = a['rawDate'] as DateTime?;
              final dateB = b['rawDate'] as DateTime?;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateA.compareTo(dateB); // Ascending order
            });

      // Get unit system
      final unitSystem = await PreferencesService.getUnitSystem();
      final unitSystemLabel = unitSystem == UnitSystem.metric
          ? 'Metric (km, L)'
          : 'Imperial (mi, gal)';
      final odometerUnit = unitSystem == UnitSystem.metric ? 'km' : 'mi';

      // Get user profile
      final profile = await ProfileRepository.getCachedFirst(refresh: false);
      final userName = profile?['full_name'] as String? ?? 'User';
      final userPhone = profile?['phone'] as String? ?? '';

      // Add page to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        userName,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      if (userPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          userPhone,
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'MILOW - Trip & Fuel Records',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Generated: ${_formatDate(DateTime.now())}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        if (dateRange != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                        if (filter != 'All') ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Filter: $filter',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Units: $unitSystemLabel',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 12),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '© ${DateTime.now().year} Milow - Trucker\'s Companion',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '>> Download Milow app for truckers & companies - Track trips, fuel & expenses effortlessly!',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue600,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          build: (context) => [
            // Summary Cards (conditionally rendered)
            if (includeSummaryBanner) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.blue50, PdfColors.white],
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPdfSummaryCard(
                      'Total Records',
                      '${recordsToExport.length}',
                      PdfColors.blue700,
                    ),
                    _buildPdfSummaryDivider(),
                    _buildPdfSummaryCard(
                      'Trips',
                      '${tripRecords.length}',
                      PdfColors.blue600,
                    ),
                    _buildPdfSummaryDivider(),
                    _buildPdfSummaryCard(
                      'Fuel Entries',
                      '${fuelRecords.length}',
                      PdfColors.orange600,
                    ),
                    _buildPdfSummaryDivider(),
                    _buildPdfSummaryCard(
                      'Total Miles',
                      tripRecords
                          .fold<double>(
                            0,
                            (sum, r) =>
                                sum +
                                ((r['rawDistance'] as num?)?.toDouble() ?? 0),
                          )
                          .toStringAsFixed(0),
                      PdfColors.green700,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // TRIPS TABLE
            if (tripRecords.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'T',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'TRIP RECORDS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      '${tripRecords.length} trips',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: _buildTripColumnWidths(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: _buildTripHeaderCells(),
                  ),
                  // Data rows
                  ...tripRecords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final trip = record['data'] as Trip;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: _buildTripDataCells(trip),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // FUEL TABLE
            if (fuelRecords.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.orange700,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'F',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange700,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'FUEL RECORDS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      '${fuelRecords.length} entries',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: _buildFuelColumnWidths(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.orange50,
                    ),
                    children: _buildFuelHeaderCells(),
                  ),
                  // Data rows
                  ...fuelRecords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final fuel = record['data'] as FuelEntry;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: _buildFuelDataCells(fuel, odometerUnit, '\$'),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      );

      // Get accessible Downloads directory for saving PDFs
      Directory? milowDocumentsDir;

      try {
        // Try to get external storage directory
        final externalStorage = await getExternalStorageDirectory();

        if (externalStorage != null) {
          // Extract the base path (before /Android/data/...)
          // For most devices: /storage/emulated/0
          String basePath;
          final externalPath = externalStorage.path;

          if (externalPath.contains('/Android/data/')) {
            basePath = externalPath.split('/Android/data/')[0];
          } else if (externalPath.contains('/Android/')) {
            basePath = externalPath.split('/Android/')[0];
          } else {
            // Fallback: try common paths
            basePath = '/storage/emulated/0';
          }

          // Use Downloads folder which is accessible through file managers
          milowDocumentsDir = Directory('$basePath/Download/Milow Documents');
        } else {
          // Fallback to application documents if external storage not available
          final documentsDirectory = await getApplicationDocumentsDirectory();
          milowDocumentsDir = Directory(
            '${documentsDirectory.path}/Milow Documents',
          );
        }
      } catch (e) {
        debugPrint('Error getting external storage: $e');
        // Fallback to application documents on error
        final documentsDirectory = await getApplicationDocumentsDirectory();
        milowDocumentsDir = Directory(
          '${documentsDirectory.path}/Milow Documents',
        );
      }

      // Create "Milow Documents" folder if it doesn't exist
      if (!await milowDocumentsDir.exists()) {
        await milowDocumentsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'milow_records_$timestamp.pdf';
      final filePath = '${milowDocumentsDir.path}/$fileName';

      // Save the PDF
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog with options
      if (mounted) {
        _showExportSuccessDialog(filePath, fileName);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        final tokens = context.tokens;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate PDF: $e',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            backgroundColor: tokens.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeS),
            ),
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSummaryDivider() {
    return pw.Container(height: 40, width: 1, color: PdfColors.grey300);
  }

  pw.Widget _buildPdfTableHeaderCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
          color: color ?? PdfColors.blue900,
        ),
        softWrap: true,
      ),
    );
  }

  pw.Widget _buildPdfTableDataCell(
    String text, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? PdfColors.grey800,
        ),
        softWrap: true,
        maxLines: 5,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Build dynamic column widths for trip table based on selected columns
  Map<int, pw.TableColumnWidth> _buildTripColumnWidths() {
    final Map<int, pw.TableColumnWidth> widths = {};
    final columns = _getOrderedTripColumns();

    for (int i = 0; i < columns.length; i++) {
      switch (columns[i]) {
        case 'tripNumber':
          widths[i] = const pw.FlexColumnWidth(1.0);
          break;
        case 'date':
          widths[i] = const pw.FlexColumnWidth(1.2);
          break;
        case 'truck':
          widths[i] = const pw.FlexColumnWidth(0.8);
          break;
        case 'trailer':
          widths[i] = const pw.FlexColumnWidth(0.8);
          break;
        case 'borderCrossing':
          widths[i] = const pw.FlexColumnWidth(1.2);
          break;
        case 'from':
          widths[i] = const pw.FlexColumnWidth(2.5);
          break;
        case 'to':
          widths[i] = const pw.FlexColumnWidth(2.5);
          break;
        case 'miles':
          widths[i] = const pw.FlexColumnWidth(0.8);
          break;
        case 'notes':
          widths[i] = const pw.FlexColumnWidth(1.5);
          break;
        case 'officialUse':
          widths[i] = const pw.FlexColumnWidth(1.2);
          break;
      }
    }
    return widths;
  }

  /// Get ordered list of selected trip columns
  List<String> _getOrderedTripColumns() {
    final order = [
      'tripNumber',
      'date',
      'truck',
      'trailer',
      'borderCrossing',
      'from',
      'to',
      'miles',
      'notes',
      'officialUse',
    ];
    return order.where((col) => _selectedTripColumns.contains(col)).toList();
  }

  /// Build header cells for trip table
  List<pw.Widget> _buildTripHeaderCells() {
    return _getOrderedTripColumns().map((col) {
      return _buildPdfTableHeaderCell(tripColumnLabels[col] ?? col);
    }).toList();
  }

  /// Build data cells for a trip row
  List<pw.Widget> _buildTripDataCells(Trip trip) {
    return _getOrderedTripColumns().map((col) {
      switch (col) {
        case 'tripNumber':
          return _buildPdfTableDataCell(
            trip.tripNumber,
            bold: true,
            color: PdfColors.blue800,
          );
        case 'date':
          return _buildPdfTableDataCell(
            DateFormat('MMM d, yyyy').format(trip.tripDate),
          );
        case 'truck':
          return _buildPdfTableDataCell(trip.truckNumber);
        case 'trailer':
          return _buildPdfTableDataCell(
            trip.trailers.isNotEmpty ? trip.trailers.join(', ') : '-',
          );
        case 'borderCrossing':
          return _buildPdfTableDataCell(trip.borderCrossing ?? '-');
        case 'from':
          return _buildPdfTableDataCell(
            trip.pickupLocations.isNotEmpty
                ? trip.pickupLocations
                      .map((l) => AddressUtils.formatForPdf(l))
                      .join('\n')
                : '-',
          );
        case 'to':
          return _buildPdfTableDataCell(
            trip.deliveryLocations.isNotEmpty
                ? trip.deliveryLocations
                      .map((l) => AddressUtils.formatForPdf(l))
                      .join('\n')
                : '-',
          );
        case 'miles':
          final miles = trip.totalDistance?.toStringAsFixed(0) ?? '-';
          return _buildPdfTableDataCell(
            '$miles ${trip.distanceUnitLabel}',
            bold: true,
            color: PdfColors.green700,
          );
        case 'notes':
          return _buildPdfTableDataCell(trip.notes ?? '-');
        case 'officialUse':
          return _buildPdfTableDataCell('');
        default:
          return _buildPdfTableDataCell('-');
      }
    }).toList();
  }

  /// Build dynamic column widths for fuel table based on selected columns
  Map<int, pw.TableColumnWidth> _buildFuelColumnWidths() {
    final Map<int, pw.TableColumnWidth> widths = {};
    final columns = _getOrderedFuelColumns();

    for (int i = 0; i < columns.length; i++) {
      switch (columns[i]) {
        case 'date':
          widths[i] = const pw.FlexColumnWidth(1.2);
          break;
        case 'type':
          widths[i] = const pw.FlexColumnWidth(0.8);
          break;
        case 'truck':
          widths[i] = const pw.FlexColumnWidth(1.0);
          break;
        case 'location':
          widths[i] = const pw.FlexColumnWidth(1.8);
          break;
        case 'quantity':
          widths[i] = const pw.FlexColumnWidth(1.0);
          break;
        case 'odometer':
          widths[i] = const pw.FlexColumnWidth(1.0);
          break;
        case 'cost':
          widths[i] = const pw.FlexColumnWidth(1.0);
          break;
      }
    }
    return widths;
  }

  /// Get ordered list of selected fuel columns
  List<String> _getOrderedFuelColumns() {
    final order = [
      'date',
      'type',
      'truck',
      'location',
      'quantity',
      'odometer',
      'cost',
    ];
    return order.where((col) => _selectedFuelColumns.contains(col)).toList();
  }

  /// Build header cells for fuel table
  List<pw.Widget> _buildFuelHeaderCells() {
    return _getOrderedFuelColumns().map((col) {
      return _buildPdfTableHeaderCell(
        fuelColumnLabels[col] ?? col,
        color: PdfColors.orange900,
      );
    }).toList();
  }

  /// Build data cells for a fuel row
  List<pw.Widget> _buildFuelDataCells(
    FuelEntry fuel,
    String odometerUnit,
    String currency,
  ) {
    return _getOrderedFuelColumns().map((col) {
      switch (col) {
        case 'date':
          return _buildPdfTableDataCell(
            DateFormat('MMM d, yyyy').format(fuel.fuelDate),
          );
        case 'type':
          return _buildPdfTableDataCell(
            fuel.isReeferFuel ? 'Reefer' : 'Truck',
            bold: true,
            color: fuel.isReeferFuel ? PdfColors.cyan700 : PdfColors.orange700,
          );
        case 'truck':
          return _buildPdfTableDataCell(
            fuel.isReeferFuel
                ? (fuel.reeferNumber ?? '-')
                : (fuel.truckNumber ?? '-'),
          );
        case 'location':
          return _buildPdfTableDataCell(
            AddressUtils.formatForPdf(fuel.location ?? ''),
          );
        case 'quantity':
          return _buildPdfTableDataCell(
            '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
          );
        case 'odometer':
          if (fuel.isReeferFuel) {
            return _buildPdfTableDataCell(
              fuel.reeferHours != null
                  ? '${fuel.reeferHours!.toStringAsFixed(1)} hrs'
                  : '-',
            );
          } else {
            return _buildPdfTableDataCell(
              fuel.odometerReading != null
                  ? '${fuel.odometerReading!.toStringAsFixed(0)} $odometerUnit'
                  : '-',
            );
          }
        case 'cost':
          return _buildPdfTableDataCell(
            '$currency${fuel.totalCost.toStringAsFixed(2)}',
            bold: true,
            color: PdfColors.green700,
          );
        default:
          return _buildPdfTableDataCell('-');
      }
    }).toList();
  }

  void _showExportSuccessDialog(String filePath, String fileName) {
    final tokens = context.tokens;
    final textColor = tokens.textPrimary;
    final secondaryTextColor = tokens.textSecondary;
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final type = isPdf ? 'PDF' : 'CSV';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeXL),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.subtleBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tokens.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: tokens.success,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$type Generated Successfully!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Saved to device storage',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        // ignore: deprecated_member_use
                        await Share.shareXFiles([
                          XFile(filePath),
                        ], text: 'Milow Records Report');
                      },
                      icon: Icon(
                        Icons.share_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'Share',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await OpenFile.open(filePath);
                      },
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Open',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
