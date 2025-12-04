import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:milow/core/models/trip.dart';
import 'package:milow/core/models/fuel_entry.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:intl/intl.dart';
import 'package:milow/features/trips/presentation/pages/add_entry_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordsListPage extends StatefulWidget {
  const RecordsListPage({super.key});

  @override
  State<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends State<RecordsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  // Real data from Supabase
  List<Map<String, dynamic>> _allRecords = [];
  bool _isLoading = true;

  // Realtime subscriptions
  RealtimeChannel? _tripsChannel;
  RealtimeChannel? _fuelChannel;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _setupRealtimeSubscriptions();
  }

  void _setupRealtimeSubscriptions() {
    final supabase = Supabase.instance.client;

    // Subscribe to trips table changes
    _tripsChannel = supabase
        .channel('records_trips')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            // Invalidate cache so dashboard fetches fresh data
            DataPrefetchService.instance.invalidateCache();
            _loadRecords();
          },
        )
        .subscribe();

    // Subscribe to fuel_entries table changes
    _fuelChannel = supabase
        .channel('records_fuel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fuel_entries',
          callback: (payload) {
            // Invalidate cache so dashboard fetches fresh data
            DataPrefetchService.instance.invalidateCache();
            _loadRecords();
          },
        )
        .subscribe();
  }

  /// Extract city and state from a full address using regex
  String _extractCityState(String address) {
    if (address.isEmpty) return address;

    // Pattern to match "City, State/Province" or "City, State ZIP"
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

    // If no match, try to extract just the city
    final parts = address.split(',');
    if (parts.length >= 2) {
      for (final part in parts) {
        final trimmed = part.trim();
        if (!RegExp(r'^\d').hasMatch(trimmed) && trimmed.isNotEmpty) {
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

    return address.length > 25 ? '${address.substring(0, 22)}...' : address;
  }

  Future<void> _loadRecords() async {
    try {
      final trips = await TripService.getTrips();
      final fuelEntries = await FuelService.getFuelEntries();

      final List<Map<String, dynamic>> combined = [];

      for (final trip in trips) {
        final pickups = trip.pickupLocations;
        final deliveries = trip.deliveryLocations;
        final route = pickups.isNotEmpty && deliveries.isNotEmpty
            ? '${_extractCityState(pickups.first)} → ${_extractCityState(deliveries.last)}'
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
            ? _extractCityState(fuel.location!)
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
    _tripsChannel?.unsubscribe();
    _fuelChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filter Records',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterOption('All', textColor),
              _buildFilterOption('Trips Only', textColor),
              _buildFilterOption('Fuel Only', textColor),
              _buildFilterOption('Short (<100 mi)', textColor),
              _buildFilterOption('Medium (100-200 mi)', textColor),
              _buildFilterOption('Long (>200 mi)', textColor),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String filter, Color textColor) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF007AFF) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              filter,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Records',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save_alt, color: textColor),
            onPressed: () => _showDownloadBottomSheet(
              textColor,
              secondaryTextColor,
              cardColor,
              borderColor,
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedFilter != 'All',
              child: Icon(Icons.filter_list, color: textColor),
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by load ID or route...',
                hintStyle: GoogleFonts.inter(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: secondaryTextColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: secondaryTextColor),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF007AFF)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: GoogleFonts.inter(color: textColor),
            ),
          ),

          // Filter chip (shown when filter is active)
          if (_selectedFilter != 'All')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      _selectedFilter,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    backgroundColor: const Color(
                      0xFF007AFF,
                    ).withValues(alpha: 0.1),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF007AFF),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = 'All';
                      });
                    },
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredRecords.length} results',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Records list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No records found',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedFilter != 'All'
                              ? 'Try adjusting your search or filter'
                              : 'Add your first trip or fuel entry',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      return Dismissible(
                        key: Key('${record['type']}_${record['id']}'),
                        background: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(12),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
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
                            // Capture scaffold messenger before async gap
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );

                            // Delete action
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(
                                  'Delete Record',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: Text(
                                  'Are you sure you want to delete ${record['id']}?',
                                  style: GoogleFonts.inter(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(
                                      'Delete',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              // Delete from Supabase
                              try {
                                final isTrip = record['type'] == 'trip';
                                final data = record['data'];

                                if (isTrip) {
                                  final trip = data as Trip;
                                  if (trip.id != null) {
                                    await TripService.deleteTrip(trip.id!);
                                  }
                                } else {
                                  final fuel = data as FuelEntry;
                                  if (fuel.id != null) {
                                    await FuelService.deleteFuelEntry(fuel.id!);
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
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                                return false; // Don't auto-dismiss, we already removed it
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
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
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      (record['type'] == 'trip'
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFF59E0B))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  record['type'] == 'trip'
                                      ? Icons.local_shipping
                                      : Icons.local_gas_station,
                                  color: record['type'] == 'trip'
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFF59E0B),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    // Top row: ID left, Value right
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          record['id'] as String? ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          record['value'] as String? ?? '',
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            record['description'] as String? ??
                                                '',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: secondaryTextColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          record['date'] as String? ?? '',
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
      _loadRecords();
    }
  }

  void _showDownloadBottomSheet(
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    DateTimeRange? tempDateRange = _selectedDateRange;
    String selectedExportFilter = _selectedFilter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calculate export count based on current selections
            final exportCount = _getExportRecords(
              selectedExportFilter,
              tempDateRange,
            ).length;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Color(0xFF007AFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Export Records',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Download as PDF file',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date Range Section
                  Text(
                    'Date Range',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Start Date
                      Expanded(
                        child: _buildDatePickerField(
                          label: 'From',
                          date: tempDateRange?.start,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          isDark: isDark,
                          onTap: () async {
                            final picked = await _showCustomDatePicker(
                              context,
                              initialDate:
                                  tempDateRange?.start ??
                                  DateTime.now().subtract(
                                    const Duration(days: 30),
                                  ),
                              firstDate: DateTime(2020),
                              lastDate: tempDateRange?.end ?? DateTime.now(),
                              isDark: isDark,
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempDateRange = DateTimeRange(
                                  start: picked,
                                  end: tempDateRange?.end ?? DateTime.now(),
                                );
                              });
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: secondaryTextColor,
                          size: 20,
                        ),
                      ),
                      // End Date
                      Expanded(
                        child: _buildDatePickerField(
                          label: 'To',
                          date: tempDateRange?.end,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          isDark: isDark,
                          onTap: () async {
                            final picked = await _showCustomDatePicker(
                              context,
                              initialDate: tempDateRange?.end ?? DateTime.now(),
                              firstDate: tempDateRange?.start ?? DateTime(2020),
                              lastDate: DateTime.now(),
                              isDark: isDark,
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempDateRange = DateTimeRange(
                                  start:
                                      tempDateRange?.start ??
                                      DateTime.now().subtract(
                                        const Duration(days: 30),
                                      ),
                                  end: picked,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick date range options
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickDateChip(
                          'Last 7 days',
                          () {
                            setModalState(() {
                              tempDateRange = DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 7),
                                ),
                                end: DateTime.now(),
                              );
                            });
                          },
                          secondaryTextColor,
                          cardColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDateChip(
                          'Biweekly',
                          () {
                            setModalState(() {
                              tempDateRange = DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 14),
                                ),
                                end: DateTime.now(),
                              );
                            });
                          },
                          secondaryTextColor,
                          cardColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDateChip(
                          'Last 30 days',
                          () {
                            setModalState(() {
                              tempDateRange = DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                end: DateTime.now(),
                              );
                            });
                          },
                          secondaryTextColor,
                          cardColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDateChip(
                          'This month',
                          () {
                            setModalState(() {
                              final now = DateTime.now();
                              tempDateRange = DateTimeRange(
                                start: DateTime(now.year, now.month, 1),
                                end: DateTime.now(),
                              );
                            });
                          },
                          secondaryTextColor,
                          cardColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDateChip(
                          'All time',
                          () {
                            setModalState(() {
                              tempDateRange = null;
                            });
                          },
                          secondaryTextColor,
                          cardColor,
                          borderColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter Selection
                  Text(
                    'Record Type',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5),
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedExportFilter,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: secondaryTextColor,
                        ),
                        dropdownColor: cardColor,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textColor,
                        ),
                        items:
                            [
                                  'All',
                                  'Trips Only',
                                  'Fuel Only',
                                  'Short (<100 mi)',
                                  'Medium (100-200 mi)',
                                  'Long (>200 mi)',
                                ]
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getFilterIcon(filter),
                                          size: 18,
                                          color: secondaryTextColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(filter),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedExportFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Record count preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: exportCount > 0
                            ? [
                                const Color(0xFF007AFF).withValues(alpha: 0.1),
                                const Color(0xFF007AFF).withValues(alpha: 0.05),
                              ]
                            : [
                                const Color(0xFFEF4444).withValues(alpha: 0.1),
                                const Color(0xFFEF4444).withValues(alpha: 0.05),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: exportCount > 0
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: exportCount > 0
                                ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                                : const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            exportCount > 0
                                ? Icons.description_outlined
                                : Icons.warning_amber_rounded,
                            color: exportCount > 0
                                ? const Color(0xFF007AFF)
                                : const Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exportCount > 0
                                    ? '$exportCount records found'
                                    : 'No records found',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: exportCount > 0
                                      ? const Color(0xFF007AFF)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              if (exportCount > 0)
                                Text(
                                  'Ready to export',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                )
                              else
                                Text(
                                  'Try adjusting your filters',
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
                  ),
                  const SizedBox(height: 24),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: exportCount > 0
                          ? () {
                              setState(() {
                                _selectedDateRange = tempDateRange;
                              });
                              Navigator.pop(context);
                              _downloadPDF(selectedExportFilter, tempDateRange);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFE5E5E5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: exportCount > 0
                                ? Colors.white
                                : secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Download PDF',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: exportCount > 0
                                  ? Colors.white
                                  : secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required Color textColor,
    required Color secondaryTextColor,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: date != null
                      ? const Color(0xFF007AFF)
                      : secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null ? _formatDate(date) : 'Select',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: date != null ? textColor : secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(
    String label,
    VoidCallback onTap,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _showCustomDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool isDark,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF007AFF),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF007AFF),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF101828),
                  ),
            dialogBackgroundColor: isDark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.all_inclusive;
      case 'Trips Only':
        return Icons.local_shipping_outlined;
      case 'Fuel Only':
        return Icons.local_gas_station_outlined;
      case 'Short (<100 mi)':
        return Icons.straighten;
      case 'Medium (100-200 mi)':
        return Icons.swap_horiz;
      case 'Long (>200 mi)':
        return Icons.route;
      default:
        return Icons.filter_list;
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

  Future<void> _downloadPDF(String filter, DateTimeRange? dateRange) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007AFF)),
      ),
    );

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Get records to export using the proper filter method
      final recordsToExport = _getExportRecords(filter, dateRange);

      // Separate trips and fuel entries
      final tripRecords = recordsToExport
          .where((r) => r['type'] == 'trip')
          .toList();
      final fuelRecords = recordsToExport
          .where((r) => r['type'] == 'fuel')
          .toList();

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
            // Summary Cards
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
                    '${tripRecords.fold<double>(0, (sum, r) => sum + ((r['rawDistance'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
                    PdfColors.green700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // TRIPS TABLE
            if (tripRecords.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: const pw.BorderRadius.only(
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
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0), // Trip #
                  1: const pw.FlexColumnWidth(1.2), // Date
                  2: const pw.FlexColumnWidth(2.0), // From (Pickup)
                  3: const pw.FlexColumnWidth(2.0), // To (Delivery)
                  4: const pw.FlexColumnWidth(0.8), // Miles
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _buildPdfTableHeaderCell('Trip #'),
                      _buildPdfTableHeaderCell('Date'),
                      _buildPdfTableHeaderCell('From (Pickup)'),
                      _buildPdfTableHeaderCell('To (Delivery)'),
                      _buildPdfTableHeaderCell('Miles'),
                    ],
                  ),
                  // Data rows
                  ...tripRecords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final trip = record['data'] as Trip;
                    final pickupLocation = trip.pickupLocations.isNotEmpty
                        ? _extractCityState(trip.pickupLocations.first)
                        : '-';
                    final deliveryLocation = trip.deliveryLocations.isNotEmpty
                        ? _extractCityState(trip.deliveryLocations.last)
                        : '-';
                    final miles = trip.totalDistance?.toStringAsFixed(0) ?? '-';

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: [
                        _buildPdfTableDataCell(
                          trip.tripNumber,
                          bold: true,
                          color: PdfColors.blue800,
                        ),
                        _buildPdfTableDataCell(
                          DateFormat('MMM d, yyyy').format(trip.tripDate),
                        ),
                        _buildPdfTableDataCell(pickupLocation),
                        _buildPdfTableDataCell(deliveryLocation),
                        _buildPdfTableDataCell(
                          '$miles ${trip.distanceUnitLabel}',
                          bold: true,
                          color: PdfColors.green700,
                        ),
                      ],
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
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange700,
                  borderRadius: const pw.BorderRadius.only(
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
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Date
                  1: const pw.FlexColumnWidth(0.8), // Type
                  2: const pw.FlexColumnWidth(1.0), // Vehicle #
                  3: const pw.FlexColumnWidth(2.0), // Location
                  4: const pw.FlexColumnWidth(1.0), // Quantity
                  5: const pw.FlexColumnWidth(1.0), // Odometer
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.orange50,
                    ),
                    children: [
                      _buildPdfTableHeaderCell(
                        'Date',
                        color: PdfColors.orange900,
                      ),
                      _buildPdfTableHeaderCell(
                        'Type',
                        color: PdfColors.orange900,
                      ),
                      _buildPdfTableHeaderCell(
                        'Vehicle #',
                        color: PdfColors.orange900,
                      ),
                      _buildPdfTableHeaderCell(
                        'Location',
                        color: PdfColors.orange900,
                      ),
                      _buildPdfTableHeaderCell(
                        'Quantity',
                        color: PdfColors.orange900,
                      ),
                      _buildPdfTableHeaderCell(
                        'Odometer ($odometerUnit)',
                        color: PdfColors.orange900,
                      ),
                    ],
                  ),
                  // Data rows
                  ...fuelRecords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final fuel = record['data'] as FuelEntry;
                    final location = fuel.location != null
                        ? _extractCityState(fuel.location!)
                        : '-';
                    final vehicleNumber = fuel.isTruckFuel
                        ? fuel.truckNumber ?? '-'
                        : fuel.reeferNumber ?? '-';
                    final odometer = fuel.odometerReading != null
                        ? '${fuel.odometerReading!.toStringAsFixed(0)} $odometerUnit'
                        : '-';

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: [
                        _buildPdfTableDataCell(
                          DateFormat('MMM d, yyyy').format(fuel.fuelDate),
                        ),
                        _buildPdfTableDataCell(
                          fuel.isTruckFuel ? 'Truck' : 'Reefer',
                          color: fuel.isTruckFuel
                              ? PdfColors.blue700
                              : PdfColors.purple700,
                        ),
                        _buildPdfTableDataCell(vehicleNumber, bold: true),
                        _buildPdfTableDataCell(location),
                        _buildPdfTableDataCell(
                          '${fuel.fuelQuantity.toStringAsFixed(1)} ${fuel.fuelUnitLabel}',
                          bold: true,
                          color: PdfColors.orange700,
                        ),
                        _buildPdfTableDataCell(
                          odometer,
                          bold: true,
                          color: PdfColors.blueGrey700,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      );

      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'milow_records_$timestamp.pdf';
      final filePath = '${directory.path}/$fileName';

      // Save the PDF
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog with options
      if (mounted) {
        _showPdfSuccessDialog(filePath, fileName);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Text('Failed to generate PDF: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
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
          fontSize: 9,
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
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? PdfColors.grey800,
        ),
        softWrap: true,
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  void _showPdfSuccessDialog(String filePath, String fileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'PDF Generated Successfully!',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder,
                      color: Color(0xFF007AFF),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Saved to: Documents folder',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF007AFF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(filePath)],
                            text: 'Milow Records Report',
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, color: Color(0xFF007AFF)),
                      label: Text(
                        'Share',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF007AFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF007AFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await OpenFile.open(filePath);
                      },
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      label: Text(
                        'Open',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
