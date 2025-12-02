import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/utils/error_handler.dart';
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
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;

  // Scroll-to-hide header
  final ScrollController _tripScrollController = ScrollController();
  final ScrollController _fuelScrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollOffset = 0;

  // Unit system
  String _distanceUnit = 'mi';
  String _fuelUnit = 'gal';

  // Trip fields
  final _tripNumberController = TextEditingController();
  final _tripTruckNumberController = TextEditingController();
  final _tripTrailerNumberController = TextEditingController();
  final _tripDateController = TextEditingController();

  // Multiple pickup locations (start locations)
  final List<TextEditingController> _pickupControllers = [];

  // Multiple delivery locations (end locations)
  final List<TextEditingController> _deliveryControllers = [];

  static const int _maxLocations = 20;

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

    // Initialize header animation
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _headerAnimationController.value = 1.0; // Start visible

    _tripScrollController.addListener(_onTripScroll);
    _fuelScrollController.addListener(_onFuelScroll);
    _loadUnitPreferences();

    // Initialize with one pickup and one delivery location
    _addPickupLocation();
    _addDeliveryLocation();

    if (widget.initialData != null) {
      _tripNumberController.text = widget.initialData!['tripNumber'] ?? '';
      _tripTruckNumberController.text =
          widget.initialData!['truckNumber'] ?? '';
      _tripTrailerNumberController.text =
          widget.initialData!['trailerNumber'] ?? '';
      // Set first pickup location from initialData
      if (widget.initialData!['startLocation'] != null &&
          _pickupControllers.isNotEmpty) {
        _pickupControllers[0].text = widget.initialData!['startLocation'] ?? '';
      }
      // Set first delivery location from initialData
      if (widget.initialData!['endLocation'] != null &&
          _deliveryControllers.isNotEmpty) {
        _deliveryControllers[0].text = widget.initialData!['endLocation'] ?? '';
      }
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
    _headerAnimationController.dispose();
    _tripScrollController.removeListener(_onTripScroll);
    _fuelScrollController.removeListener(_onFuelScroll);
    _tripScrollController.dispose();
    _fuelScrollController.dispose();
    _tabController.dispose();
    _tripNumberController.dispose();
    _tripDateController.dispose();
    // Dispose pickup controllers
    for (final controller in _pickupControllers) {
      controller.dispose();
    }
    // Dispose delivery controllers
    for (final controller in _deliveryControllers) {
      controller.dispose();
    }
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

  // Methods to manage pickup locations
  void _addPickupLocation() {
    if (_pickupControllers.length < _maxLocations) {
      setState(() {
        _pickupControllers.add(TextEditingController());
      });
    }
  }

  void _removePickupLocation(int index) {
    if (_pickupControllers.length > 1) {
      setState(() {
        _pickupControllers[index].dispose();
        _pickupControllers.removeAt(index);
      });
    }
  }

  // Methods to manage delivery locations
  void _addDeliveryLocation() {
    if (_deliveryControllers.length < _maxLocations) {
      setState(() {
        _deliveryControllers.add(TextEditingController());
      });
    }
  }

  void _removeDeliveryLocation(int index) {
    if (_deliveryControllers.length > 1) {
      setState(() {
        _deliveryControllers[index].dispose();
        _deliveryControllers.removeAt(index);
      });
    }
  }

  // Build pickup location fields with add/remove buttons
  List<Widget> _buildPickupLocationFields() {
    final fields = <Widget>[];
    for (int i = 0; i < _pickupControllers.length; i++) {
      final isLast = i == _pickupControllers.length - 1;
      final canAdd = _pickupControllers.length < _maxLocations;
      final canRemove = _pickupControllers.length > 1;

      fields.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _pickupControllers[i],
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.streetAddress,
                  decoration: _inputDecoration(
                    hint: i == 0 ? 'City, State' : 'Additional pickup ${i + 1}',
                    prefixIcon: Icons.location_on,
                    suffixIcon: Icons.my_location,
                    onSuffixTap: () => _getLocationFor(_pickupControllers[i]),
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _removePickupLocation(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ],
              if (isLast && canAdd) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: _addPickupLocation,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return fields;
  }

  // Build delivery location fields with add/remove buttons
  List<Widget> _buildDeliveryLocationFields() {
    final fields = <Widget>[];
    for (int i = 0; i < _deliveryControllers.length; i++) {
      final isLast = i == _deliveryControllers.length - 1;
      final canAdd = _deliveryControllers.length < _maxLocations;
      final canRemove = _deliveryControllers.length > 1;

      fields.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _deliveryControllers[i],
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.streetAddress,
                  decoration: _inputDecoration(
                    hint: i == 0
                        ? 'City, State'
                        : 'Additional delivery ${i + 1}',
                    prefixIcon: Icons.location_on,
                    suffixIcon: Icons.my_location,
                    onSuffixTap: () => _getLocationFor(_deliveryControllers[i]),
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _removeDeliveryLocation(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ],
              if (isLast && canAdd) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: _addDeliveryLocation,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return fields;
  }

  void _onTripScroll() {
    _handleScroll(_tripScrollController);
  }

  void _onFuelScroll() {
    _handleScroll(_fuelScrollController);
  }

  void _handleScroll(ScrollController controller) {
    final currentOffset = controller.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    // Only trigger hide/show after scrolling a threshold amount
    if (scrollDelta > 3 && currentOffset > 50 && _isHeaderVisible) {
      // Scrolling down - hide header
      _isHeaderVisible = false;
      _headerAnimationController.reverse();
    } else if (scrollDelta < -3 && !_isHeaderVisible) {
      // Scrolling up - show header
      _isHeaderVisible = true;
      _headerAnimationController.forward();
    } else if (currentOffset <= 0 && !_isHeaderVisible) {
      // Always show header when at top
      _isHeaderVisible = true;
      _headerAnimationController.forward();
    }

    _lastScrollOffset = currentOffset;
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
        ErrorHandler.showError(context, e);
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
            // Animated Header and Tabs with smooth slide + fade
            SizeTransition(
              sizeFactor: _headerAnimation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _headerAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              ),
            ),
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
            controller: _tripScrollController,
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
                // Pickup Locations Section
                _buildLabel(
                  'Pickup Location${_pickupControllers.length > 1 ? 's' : ''}',
                ),
                const SizedBox(height: 8),
                ..._buildPickupLocationFields(),
                const SizedBox(height: 16),
                // Delivery Locations Section
                _buildLabel(
                  'Delivery Location${_deliveryControllers.length > 1 ? 's' : ''}',
                ),
                const SizedBox(height: 8),
                ..._buildDeliveryLocationFields(),
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
                    onPressed: _validateAndSaveTrip,
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

  void _validateAndSaveTrip() {
    // Check trip number
    if (_tripNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter trip number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check truck number
    if (_tripTruckNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter truck number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check start odometer
    if (_tripStartOdometerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter start odometer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if all pickup locations are filled
    for (int i = 0; i < _pickupControllers.length; i++) {
      if (_pickupControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _pickupControllers.length > 1
                  ? 'Please fill pickup location ${i + 1} or remove it'
                  : 'Please enter pickup location',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check if all delivery locations are filled
    for (int i = 0; i < _deliveryControllers.length; i++) {
      if (_deliveryControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _deliveryControllers.length > 1
                  ? 'Please fill delivery location ${i + 1} or remove it'
                  : 'Please enter delivery location',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // All validations passed - save the trip
    Navigator.pop(context);
  }

  Widget _buildAddFuelTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _fuelScrollController,
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
