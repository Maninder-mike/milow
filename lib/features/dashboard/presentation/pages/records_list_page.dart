import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:milow/core/services/preferences_service.dart';

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
  String _distanceUnit = 'mi';
  String _fuelUnit = 'gal';

  @override
  void initState() {
    super.initState();
    _loadUnitPreferences();
  }

  Future<void> _loadUnitPreferences() async {
    final distanceUnit = await PreferencesService.getDistanceUnit();
    final fuelUnit = await PreferencesService.getVolumeUnit();
    setState(() {
      _distanceUnit = distanceUnit;
      _fuelUnit = fuelUnit;
    });
  }

  // Dummy data for records (trips and fuel)
  final List<Map<String, String>> _allRecords = const [
    {
      'id': 'Trip #1247',
      'type': 'trip',
      'description': 'Dallas → Houston',
      'date': 'Nov 29, 2025',
      'value': '245 mi',
    },
    {
      'id': 'Fuel #F-892',
      'type': 'fuel',
      'description': 'Shell Station, Austin',
      'date': 'Nov 28, 2025',
      'value': '85 gal',
    },
    {
      'id': 'Trip #1246',
      'type': 'trip',
      'description': 'Austin → San Antonio',
      'date': 'Nov 28, 2025',
      'value': '80 mi',
    },
    {
      'id': 'Fuel #F-891',
      'type': 'fuel',
      'description': 'Pilot, Phoenix',
      'date': 'Nov 27, 2025',
      'value': '120 gal',
    },
    {
      'id': 'Trip #1245',
      'type': 'trip',
      'description': 'Phoenix → Tucson',
      'date': 'Nov 27, 2025',
      'value': '116 mi',
    },
    {
      'id': 'Fuel #F-890',
      'type': 'fuel',
      'description': 'Love\'s, Denver',
      'date': 'Nov 26, 2025',
      'value': '95 gal',
    },
    {
      'id': 'Trip #1244',
      'type': 'trip',
      'description': 'Denver → Colorado Springs',
      'date': 'Nov 26, 2025',
      'value': '70 mi',
    },
    {
      'id': 'Trip #1243',
      'type': 'trip',
      'description': 'Las Vegas → LA',
      'date': 'Nov 25, 2025',
      'value': '270 mi',
    },
    {
      'id': 'Fuel #F-889',
      'type': 'fuel',
      'description': 'TA, Las Vegas',
      'date': 'Nov 25, 2025',
      'value': '110 gal',
    },
    {
      'id': 'Trip #1242',
      'type': 'trip',
      'description': 'Seattle → Portland',
      'date': 'Nov 24, 2025',
      'value': '175 mi',
    },
    {
      'id': 'Fuel #F-888',
      'type': 'fuel',
      'description': 'Flying J, Seattle',
      'date': 'Nov 24, 2025',
      'value': '78 gal',
    },
    {
      'id': 'Trip #1241',
      'type': 'trip',
      'description': 'Chicago → Milwaukee',
      'date': 'Nov 23, 2025',
      'value': '92 mi',
    },
    {
      'id': 'Trip #1240',
      'type': 'trip',
      'description': 'Miami → Orlando',
      'date': 'Nov 22, 2025',
      'value': '235 mi',
    },
    {
      'id': 'Fuel #F-887',
      'type': 'fuel',
      'description': 'Wawa, Miami',
      'date': 'Nov 22, 2025',
      'value': '88 gal',
    },
    {
      'id': 'Trip #1239',
      'type': 'trip',
      'description': 'Atlanta → Charlotte',
      'date': 'Nov 21, 2025',
      'value': '245 mi',
    },
  ];

  List<Map<String, String>> get _filteredRecords {
    return _allRecords.where((record) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          record['id']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          record['description']!.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Parse value for distance-based filtering (trips only)
      bool matchesFilter = true;
      if (_selectedFilter != 'All') {
        if (record['type'] == 'trip') {
          final miles =
              int.tryParse(record['value']!.replaceAll(' mi', '')) ?? 0;
          matchesFilter =
              (_selectedFilter == 'Short (<100 mi)' && miles < 100) ||
              (_selectedFilter == 'Medium (100-200 mi)' &&
                  miles >= 100 &&
                  miles <= 200) ||
              (_selectedFilter == 'Long (>200 mi)' && miles > 200) ||
              (_selectedFilter == 'Trips Only');
        } else if (record['type'] == 'fuel') {
          matchesFilter = _selectedFilter == 'Fuel Only';
        }
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
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
            child: _filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
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
                          'Try adjusting your search or filter',
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
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      return Dismissible(
                        key: Key(record['id']!),
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
                            // Delete action
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
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
                                        Navigator.pop(context, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                        onDismissed: (direction) {
                          if (direction == DismissDirection.endToStart) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${record['id']} deleted'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      (record['type'] == 'trip'
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFF59E0B))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  record['type'] == 'trip'
                                      ? Icons.local_shipping
                                      : Icons.local_gas_station,
                                  color: record['type'] == 'trip'
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFF59E0B),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record['id']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      record['description']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
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
                                    record['value']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: record['type'] == 'trip'
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record['date']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
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
    Map<String, String> record,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    final isTrip = record['type'] == 'trip';
    final descriptionController = TextEditingController(
      text: record['description'],
    );
    final valueController = TextEditingController(
      text: record['value']!.replaceAll(' mi', '').replaceAll(' gal', ''),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  Icon(
                    isTrip ? Icons.local_shipping : Icons.local_gas_station,
                    color: isTrip
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Modify ${record['id']}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isTrip ? 'Route' : 'Location',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                style: GoogleFonts.inter(color: textColor),
                decoration: InputDecoration(
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
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTrip ? _distanceUnit : _fuelUnit,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: textColor),
                decoration: InputDecoration(
                  suffixText: isTrip ? _distanceUnit : _fuelUnit,
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
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${record['id']} updated'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadBottomSheet(
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
    Color borderColor,
  ) {
    DateTimeRange? tempDateRange = _selectedDateRange;
    String selectedExportFilter = _selectedFilter;

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
                      const Icon(Icons.save_alt, color: Color(0xFF007AFF)),
                      const SizedBox(width: 10),
                      Text(
                        'Download Records as PDF',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date Range Picker
                  Text(
                    'Date Range',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        initialDateRange:
                            tempDateRange ??
                            DateTimeRange(
                              start: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              end: DateTime.now(),
                            ),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF007AFF),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          tempDateRange = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tempDateRange != null
                                  ? '${_formatDate(tempDateRange!.start)} - ${_formatDate(tempDateRange!.end)}'
                                  : 'Select date range',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: tempDateRange != null
                                    ? textColor
                                    : secondaryTextColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter Selection
                  Text(
                    'Filter',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedExportFilter,
                        isExpanded: true,
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
                                    child: Text(filter),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF007AFF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_filteredRecords.length} records will be exported',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = tempDateRange;
                        });
                        Navigator.pop(context);
                        _downloadPDF(selectedExportFilter, tempDateRange);
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: Text(
                        'Download PDF',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

      // Get records to export
      final recordsToExport = _filteredRecords;

      // Add page to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Milow Records Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    'Generated: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              if (filter != 'All')
                pw.Text(
                  'Filter: $filter',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              if (dateRange != null)
                pw.Text(
                  'Date Range: ${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Milow - Trip & Fuel Records',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          build: (context) => [
            // Summary section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryItem(
                    'Total Records',
                    '${recordsToExport.length}',
                    PdfColors.blue700,
                  ),
                  _buildPdfSummaryItem(
                    'Trips',
                    '${recordsToExport.where((r) => r['type'] == 'trip').length}',
                    PdfColors.blue700,
                  ),
                  _buildPdfSummaryItem(
                    'Fuel Entries',
                    '${recordsToExport.where((r) => r['type'] == 'fuel').length}',
                    PdfColors.orange700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Records table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue700),
                  children: [
                    _buildPdfTableHeader('ID'),
                    _buildPdfTableHeader('Type'),
                    _buildPdfTableHeader('Description'),
                    _buildPdfTableHeader('Date'),
                    _buildPdfTableHeader('Value'),
                  ],
                ),
                // Data rows
                ...recordsToExport.map(
                  (record) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: recordsToExport.indexOf(record) % 2 == 0
                          ? PdfColors.white
                          : PdfColors.grey50,
                    ),
                    children: [
                      _buildPdfTableCell(record['id']!),
                      _buildPdfTableCell(
                        record['type'] == 'trip' ? 'Trip' : 'Fuel',
                        color: record['type'] == 'trip'
                            ? PdfColors.blue700
                            : PdfColors.orange700,
                      ),
                      _buildPdfTableCell(record['description']!),
                      _buildPdfTableCell(record['date']!),
                      _buildPdfTableCell(
                        record['value']!,
                        color: record['type'] == 'trip'
                            ? PdfColors.blue700
                            : PdfColors.orange700,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  pw.Widget _buildPdfSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildPdfTableCell(
    String text, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? PdfColors.grey800,
        ),
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
