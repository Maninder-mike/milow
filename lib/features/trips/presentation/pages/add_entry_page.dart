import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:milow/core/services/preferences_service.dart';

class AddEntryPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddEntryPage({super.key, this.initialData});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Unit system
  String _distanceUnit = 'mi';
  String _fuelUnit = 'gal';

  // Trip fields
  final _tripNumberController = TextEditingController();
  final _tripTruckNumberController = TextEditingController();
  final _tripTrailerNumberController = TextEditingController();
  final _tripDateController = TextEditingController();
  final _tripStartLocationController = TextEditingController();
  final _tripEndLocationController = TextEditingController();
  final _tripStartOdometerController = TextEditingController();
  final _tripEndOdometerController = TextEditingController();
  final _tripNotesController = TextEditingController();

  // Fuel fields
  final _fuelDateController = TextEditingController();
  final _truckNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _fuelQuantityController = TextEditingController();
  final _fuelPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadUnitPreferences();

    if (widget.initialData != null) {
      _tripNumberController.text = widget.initialData!['tripNumber'] ?? '';
      _tripTruckNumberController.text =
          widget.initialData!['truckNumber'] ?? '';
      _tripTrailerNumberController.text =
          widget.initialData!['trailerNumber'] ?? '';
      _tripStartLocationController.text =
          widget.initialData!['startLocation'] ?? '';
      _tripEndLocationController.text =
          widget.initialData!['endLocation'] ?? '';
      _tripNotesController.text = widget.initialData!['notes'] ?? '';

      // Handle date if present
      if (widget.initialData!['date'] != null) {
        debugPrint('Parsing date: ${widget.initialData!['date']}');
        try {
          final dateStr = widget.initialData!['date'] as String;
          // Try to parse the date string (format: "11/12/2025 8:00 AM")
          final parts = dateStr.split(' ');
          if (parts.length >= 2) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              final month = int.parse(dateParts[0]);
              final day = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);

              // Parse time
              final timePart = parts[1];
              final amPm = parts.length > 2 ? parts[2] : '';
              final timeComponents = timePart.split(':');
              int hour = int.parse(timeComponents[0]);
              final minute = timeComponents.length > 1
                  ? int.parse(timeComponents[1])
                  : 0;

              // Convert to 24-hour format
              if (amPm.toUpperCase() == 'PM' && hour != 12) {
                hour += 12;
              } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
                hour = 0;
              }

              final parsedDate = DateTime(year, month, day, hour, minute);
              _tripDateController.text = _formatDateTime(parsedDate);
              debugPrint(
                'Date parsed successfully: ${_tripDateController.text}',
              );
            }
          }
        } catch (e) {
          // If parsing fails, leave as current time
          debugPrint('Failed to parse date: $e');
        }
      }
    }

    if (_tripDateController.text.isEmpty) {
      _tripDateController.text = _formatDateTime(DateTime.now());
    }
    _fuelDateController.text = _formatDateTime(DateTime.now());
  }

  Future<void> _loadUnitPreferences() async {
    final distanceUnit = await PreferencesService.getDistanceUnit();
    final fuelUnit = await PreferencesService.getVolumeUnit();
    setState(() {
      _distanceUnit = distanceUnit;
      _fuelUnit = fuelUnit;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripNumberController.dispose();
    _tripDateController.dispose();
    _tripStartLocationController.dispose();
    _tripEndLocationController.dispose();
    _tripStartOdometerController.dispose();
    _tripEndOdometerController.dispose();
    _tripNotesController.dispose();
    _fuelDateController.dispose();
    _truckNumberController.dispose();
    _locationController.dispose();
    _odometerController.dispose();
    _fuelQuantityController.dispose();
    _fuelPriceController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
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
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}    $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _getLocationFor(TextEditingController controller) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions permanently denied'),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address += '${place.street}, ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += '${place.locality}, ';
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address += '${place.administrativeArea} ';
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          address += place.postalCode!;
        }

        setState(() {
          controller.text = address.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Entry',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Track your trips and fuel',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF667085),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Add Trip'),
                  Tab(text: 'Add Fuel'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildAddTripTab(), _buildAddFuelTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTripTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Trip Number'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tripNumberController,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  decoration: _inputDecoration(
                    hint: 'e.g., TR-12345',
                    prefixIcon: Icons.tag,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Truck Number'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tripTruckNumberController,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.text,
                            decoration: _inputDecoration(
                              hint: 'e.g., T-101',
                              prefixIcon: Icons.local_shipping,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Trailer (Optional)'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tripTrailerNumberController,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.text,
                            decoration: _inputDecoration(
                              hint: 'e.g., TL-202',
                              prefixIcon: Icons.rv_hookup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Date & Time'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tripDateController,
                  readOnly: true,
                  decoration: _inputDecoration(
                    hint: 'Tap to select',
                    prefixIcon: Icons.calendar_today,
                  ),
                  onTap: () => _selectDateTime(_tripDateController),
                ),
                const SizedBox(height: 20),
                Text(
                  'ROUTE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF667085),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLabel('Start Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tripStartLocationController,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.streetAddress,
                  decoration: _inputDecoration(
                    hint: 'City, State',
                    prefixIcon: Icons.location_on,
                    suffixIcon: Icons.my_location,
                    onSuffixTap: () =>
                        _getLocationFor(_tripStartLocationController),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('End Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tripEndLocationController,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.streetAddress,
                  decoration: _inputDecoration(
                    hint: 'City, State',
                    prefixIcon: Icons.location_on,
                    suffixIcon: Icons.my_location,
                    onSuffixTap: () =>
                        _getLocationFor(_tripEndLocationController),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ODOMETER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF667085),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Start Odometer'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tripStartOdometerController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              hint: _distanceUnit,
                              prefixIcon: Icons.speed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('End Odometer'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tripEndOdometerController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              hint: _distanceUnit,
                              prefixIcon: Icons.speed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Notes (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tripNotesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  decoration: _inputDecoration(
                    hint: 'Any additional details',
                    prefixIcon: Icons.notes,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
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
          ),
        ),
      ],
    );
  }

  Widget _buildAddFuelTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Date & Time'),
                const SizedBox(height: 8),
                TextField(
                  controller: _fuelDateController,
                  readOnly: true,
                  decoration: _inputDecoration(
                    hint: 'Tap to select',
                    prefixIcon: Icons.calendar_today,
                  ),
                  onTap: () => _selectDateTime(_fuelDateController),
                ),
                const SizedBox(height: 16),
                _buildLabel('Truck Number'),
                const SizedBox(height: 8),
                TextField(
                  controller: _truckNumberController,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  decoration: _inputDecoration(
                    hint: 'e.g., T-101',
                    prefixIcon: Icons.local_shipping,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.streetAddress,
                  decoration: _inputDecoration(
                    hint: 'Gas station or city',
                    prefixIcon: Icons.location_on,
                    suffixIcon: Icons.my_location,
                    onSuffixTap: () => _getLocationFor(_locationController),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Odometer Reading'),
                const SizedBox(height: 8),
                TextField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    hint: 'Current $_distanceUnit',
                    prefixIcon: Icons.speed,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Fuel Quantity ($_fuelUnit)'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fuelQuantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              hint: '0.0',
                              prefixIcon: Icons.local_gas_station,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Price per $_fuelUnit'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fuelPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              hint: '0.00',
                              prefixIcon: Icons.attach_money,
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
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
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
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        setState(() {
          controller.text = _formatDateTime(dateTime);
        });
      }
    }
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF98A2B3),
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF007AFF), size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: const Color(0xFF007AFF), size: 20),
              onPressed: onSuffixTap,
            )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
