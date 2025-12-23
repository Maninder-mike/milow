import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/utils/error_handler.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/fuel_service.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/utils/unit_utils.dart';
import 'package:milow/core/services/prediction_service.dart';

class AddEntryPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Trip? editingTrip;
  final FuelEntry? editingFuel;
  final int initialTab;

  const AddEntryPage({
    super.key,
    this.initialData,
    this.editingTrip,
    this.editingFuel,
    this.initialTab = 0,
  });

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
  String _currency = 'USD';
  bool _isReeferFuel = false;
  bool _defFromYard = false; // [NEW] DEF from Yard toggle
  bool _isSaving = false;

  // Trip fields
  final _tripNumberController = TextEditingController();
  final _tripTruckNumberController = TextEditingController();
  final List<TextEditingController> _trailerControllers =
      []; // Multiple trailers
  final _borderCrossingController = TextEditingController();
  final _tripDateController = TextEditingController();

  // Border crossing dropdown
  List<String> _borderCrossings = [];
  String? _selectedBorderCrossing;

  // Multiple pickup locations (start locations)
  final List<TextEditingController> _pickupControllers = [];

  // Multiple delivery locations (end locations)
  final List<TextEditingController> _deliveryControllers = [];

  static const int _maxLocations = 20;
  static const int _maxTrailers = 3;

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
  final TextEditingController _defQuantityController =
      TextEditingController(); // [NEW] DEF Quantity
  final TextEditingController _defPriceController =
      TextEditingController(); // [NEW] DEF Price

  // Fuel type: false = Truck Fuel, true = Reefer Fuel
  // This variable is now declared above with other unit system variables.

  // Edit mode flag
  bool get _isEditMode =>
      widget.editingTrip != null || widget.editingFuel != null;

  // FocusNodes for Autocomplete
  final _tripTruckFocusNode = FocusNode();
  final List<FocusNode> _trailerFocusNodes = []; // Multiple trailers

  final List<FocusNode> _pickupFocusNodes = [];
  final List<FocusNode> _deliveryFocusNodes = [];
  final _truckFocusNode = FocusNode(); // For Fuel
  final _locationFocusNode = FocusNode(); // For Fuel

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

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
    _prefillBorderCrossing();

    // Add listeners for total cost preview
    _fuelQuantityController.addListener(_onFuelFieldChanged);
    _fuelPriceController.addListener(_onFuelFieldChanged);
    _defQuantityController.addListener(_onFuelFieldChanged); // [NEW]
    _defPriceController.addListener(_onFuelFieldChanged); // [NEW]

    // Initialize with one pickup and one delivery location
    _addPickupLocation();
    _addDeliveryLocation();
    _addTrailer();

    // Handle edit mode for Trip
    if (widget.editingTrip != null) {
      _prefillTripData(widget.editingTrip!);
    }
    // Handle edit mode for FuelEntry
    else if (widget.editingFuel != null) {
      _prefillFuelData(widget.editingFuel!);
    }
    // Handle legacy initialData
    else if (widget.initialData != null) {
      _tripNumberController.text = widget.initialData!['tripNumber'] ?? '';
      _tripTruckNumberController.text =
          widget.initialData!['truckNumber'] ?? '';

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
      bool dateParsed = false;
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
              dateParsed = true;
              debugPrint(
                'Date parsed successfully: ${_tripDateController.text}',
              );
            }
          }
        } catch (e) {
          // If parsing fails, will set to today's date below
          debugPrint('Failed to parse date: $e');
        }
      }

      // If date was not parsed from shared message, set to today's date
      if (!dateParsed) {
        _tripDateController.text = _formatDateTime(DateTime.now());
        debugPrint('Setting date to today: ${_tripDateController.text}');
      }
    }

    // Set default dates if controllers are empty (for non-shared entry creation)
    if (_tripDateController.text.isEmpty) {
      _tripDateController.text = _formatDateTime(DateTime.now());
    }
    if (_fuelDateController.text.isEmpty) {
      _fuelDateController.text = _formatDateTime(DateTime.now());
    }
  }

  void _prefillTripData(Trip trip) {
    _tripNumberController.text = trip.tripNumber;
    _tripTruckNumberController.text = trip.truckNumber;
    _borderCrossingController.text = trip.borderCrossing ?? '';
    _selectedBorderCrossing = trip.borderCrossing;
    _tripDateController.text = _formatDateTime(trip.tripDate);

    // Restored trailer prefill
    if (trip.trailers.isNotEmpty) {
      // Clear initial empty trailer if present
      if (_trailerControllers.isNotEmpty &&
          _trailerControllers[0].text.isEmpty) {
        _trailerControllers[0].dispose();
        _trailerControllers.removeAt(0);
        _trailerFocusNodes[0].dispose();
        _trailerFocusNodes.removeAt(0);
      }

      for (final trailer in trip.trailers) {
        _addTrailer(trailer);
      }
    }
    // Ensure at least one field exists
    if (_trailerControllers.isEmpty) {
      _addTrailer();
    }

    // Fill pickup locations
    if (trip.pickupLocations.isNotEmpty) {
      _pickupControllers[0].text = trip.pickupLocations[0];
      for (int i = 1; i < trip.pickupLocations.length; i++) {
        _addPickupLocation();
        _pickupControllers[i].text = trip.pickupLocations[i];
      }
    }

    // Fill delivery locations
    if (trip.deliveryLocations.isNotEmpty) {
      _deliveryControllers[0].text = trip.deliveryLocations[0];
      for (int i = 1; i < trip.deliveryLocations.length; i++) {
        _addDeliveryLocation();
        _deliveryControllers[i].text = trip.deliveryLocations[i];
      }
    }

    // Fill odometer readings
    if (trip.startOdometer != null) {
      _tripStartOdometerController.text = trip.startOdometer!.toStringAsFixed(
        0,
      );
    }
    if (trip.endOdometer != null) {
      _tripEndOdometerController.text = trip.endOdometer!.toStringAsFixed(0);
    }

    // Fill notes
    if (trip.notes != null) {
      _tripNotesController.text = trip.notes!;
    }

    // Set distance unit
    _distanceUnit = trip.distanceUnit;
  }

  void _prefillFuelData(FuelEntry fuel) {
    _fuelDateController.text = _formatDateTime(fuel.fuelDate);
    _isReeferFuel = fuel.isReeferFuel;

    // Fill truck/reefer number
    if (fuel.isTruckFuel && fuel.truckNumber != null) {
      _truckNumberController.text = fuel.truckNumber!;
    } else if (fuel.isReeferFuel && fuel.reeferNumber != null) {
      _truckNumberController.text = fuel.reeferNumber!;
    }

    // Fill location
    if (fuel.location != null) {
      _locationController.text = fuel.location!;
    }

    // Fill odometer/reefer hours
    if (fuel.isTruckFuel && fuel.odometerReading != null) {
      _odometerController.text = fuel.odometerReading!.toStringAsFixed(0);
    } else if (fuel.isReeferFuel && fuel.reeferHours != null) {
      _odometerController.text = fuel.reeferHours!.toStringAsFixed(1);
    }

    // Fill fuel quantity and price
    _fuelQuantityController.text = fuel.fuelQuantity.toStringAsFixed(2);
    _fuelPriceController.text = fuel.pricePerUnit.toStringAsFixed(3);

    // Pre-fill DEF if editing
    _defQuantityController.text = fuel.defQuantity > 0
        ? fuel.defQuantity.toString()
        : '';
    _defPriceController.text = fuel.defPrice > 0
        ? fuel.defPrice.toString()
        : '';
    _defFromYard = fuel.defFromYard;

    // Set units
    _fuelUnit = fuel.fuelUnit;
    _distanceUnit = fuel.distanceUnit;
    _currency = fuel.currency;
  }

  Future<void> _loadUnitPreferences() async {
    final distanceUnit = await PreferencesService.getDistanceUnit();
    final fuelUnit = await PreferencesService.getVolumeUnit();

    // Get currency from user profile country
    final profile = await ProfileService.getProfile();
    final country = profile?['country'] as String?;
    final currency = UnitUtils.getCurrency(country);

    setState(() {
      _distanceUnit = distanceUnit;
      _fuelUnit = fuelUnit;
      _currency = currency;
    });
  }

  /// Load border crossings and prefill with most frequently used
  Future<void> _prefillBorderCrossing() async {
    try {
      final trips = await TripService.getTrips();
      if (trips.isEmpty) return;

      // Count frequency of each border crossing
      final Map<String, int> borderFrequency = {};
      for (final trip in trips) {
        if (trip.borderCrossing != null && trip.borderCrossing!.isNotEmpty) {
          borderFrequency[trip.borderCrossing!] =
              (borderFrequency[trip.borderCrossing!] ?? 0) + 1;
        }
      }

      if (borderFrequency.isEmpty) return;

      // Sort by frequency (most used first)
      final sortedBorders = borderFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final borders = sortedBorders.map((e) => e.key).toList();
      final mostFrequent = borders.isNotEmpty ? borders.first : null;

      if (mounted) {
        setState(() {
          _borderCrossings = borders;
          // In edit mode, use the trip's border crossing
          if (_isEditMode && widget.editingTrip != null) {
            final tripBorder = widget.editingTrip!.borderCrossing;
            if (tripBorder != null && tripBorder.isNotEmpty) {
              // Add to list if not already present
              if (!_borderCrossings.contains(tripBorder)) {
                _borderCrossings.insert(0, tripBorder);
              }
              _selectedBorderCrossing = tripBorder;
              _borderCrossingController.text = tripBorder;
            }
          } else if (mostFrequent != null) {
            // For new trips, select most frequent
            _selectedBorderCrossing = mostFrequent;
            _borderCrossingController.text = mostFrequent;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to prefill border crossing: $e');
    }
  }

  /// Show dialog to add a new border crossing
  Future<void> _showAddBorderCrossingDialog() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Border Crossing',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF101828),
          ),
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g., Windsor-Detroit',
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF007AFF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.inter(
                color: const Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_borderCrossings.contains(result)) {
          _borderCrossings.insert(0, result);
        }
        _selectedBorderCrossing = result;
        _borderCrossingController.text = result;
      });
    }
  }

  void _onFuelFieldChanged() {
    // Trigger rebuild to update total cost preview
    setState(() {});
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _tripScrollController.removeListener(_onTripScroll);
    _fuelScrollController.removeListener(_onFuelScroll);
    _fuelQuantityController.removeListener(_onFuelFieldChanged);
    _fuelPriceController.removeListener(_onFuelFieldChanged);
    _defQuantityController.removeListener(_onFuelFieldChanged); // [NEW]
    _defPriceController.removeListener(_onFuelFieldChanged); // [NEW]
    _tripScrollController.dispose();
    _fuelScrollController.dispose();
    _tabController.dispose();
    _tripNumberController.dispose();
    for (final controller in _trailerControllers) {
      controller.dispose();
    }
    _borderCrossingController.dispose();
    _tripDateController.dispose();
    // Dispose pickup controllers
    for (final controller in _pickupControllers) {
      controller.dispose();
    }
    // Dispose delivery controllers
    for (final controller in _deliveryControllers) {
      controller.dispose();
    }
    // Dispose trailer controllers

    _tripStartOdometerController.dispose();
    _tripEndOdometerController.dispose();
    _tripNotesController.dispose();
    _fuelDateController.dispose();
    _truckNumberController.dispose();
    _locationController.dispose();
    _odometerController.dispose();
    _fuelQuantityController.dispose();
    _fuelPriceController.dispose();
    _defQuantityController.dispose(); // [NEW]
    _defPriceController.dispose(); // [NEW]

    // Dispose FocusNodes
    _tripTruckFocusNode.dispose();
    for (final node in _trailerFocusNodes) {
      node.dispose();
    }
    _truckFocusNode.dispose();
    _locationFocusNode.dispose();

    for (var node in _pickupFocusNodes) {
      node.dispose();
    }
    for (var node in _deliveryFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  // Methods to manage pickup locations
  void _addPickupLocation([String? location]) {
    if (_pickupControllers.length < _maxLocations) {
      setState(() {
        final controller = TextEditingController(text: location);
        _pickupControllers.add(controller);
        _pickupFocusNodes.add(FocusNode());
      });
    }
  }

  void _removePickupLocation(int index) {
    if (_pickupControllers.length > 1) {
      setState(() {
        _pickupControllers[index].dispose();
        _pickupControllers.removeAt(index);
        _pickupFocusNodes[index].dispose();
        _pickupFocusNodes.removeAt(index);
      });
    }
  }

  // Methods to manage delivery locations
  void _addDeliveryLocation([String? location]) {
    if (_deliveryControllers.length < _maxLocations) {
      setState(() {
        final controller = TextEditingController(text: location);
        _deliveryControllers.add(controller);
        _deliveryFocusNodes.add(FocusNode());
      });
    }
  }

  void _removeDeliveryLocation(int index) {
    if (_deliveryControllers.length > 1) {
      setState(() {
        _deliveryControllers[index].dispose();
        _deliveryControllers.removeAt(index);
        _deliveryFocusNodes[index].dispose();
        _deliveryFocusNodes.removeAt(index);
      });
    }
  }

  // Build border crossing dropdown with add/edit capability
  Widget _buildBorderCrossingDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final hintColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Dropdown button
          Expanded(
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<String>(
                  value: _selectedBorderCrossing,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down, color: hintColor),
                  hint: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: hintColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Select or add border',
                        style: GoogleFonts.inter(
                          color: hintColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  dropdownColor: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: [
                    // Existing border crossings
                    ..._borderCrossings.map(
                      (border) => DropdownMenuItem<String>(
                        value: border,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              color: Color(0xFF007AFF),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                border,
                                style: GoogleFonts.inter(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBorderCrossing = value;
                      _borderCrossingController.text = value ?? '';
                    });
                  },
                ),
              ),
            ),
          ),
          // Add button
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: IconButton(
              onPressed: _showAddBorderCrossingDialog,
              icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
              tooltip: 'Add new border crossing',
            ),
          ),
          // Clear button (only show if a value is selected)
          if (_selectedBorderCrossing != null) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor)),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _selectedBorderCrossing = null;
                    _borderCrossingController.text = '';
                  });
                },
                icon: Icon(Icons.clear, color: Colors.red.shade400, size: 20),
                tooltip: 'Clear selection',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData prefixIcon,
    required Future<Iterable<String>> Function(String) optionsBuilder,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return optionsBuilder(textEditingValue.text);
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  textCapitalization: textCapitalization,
                  decoration: _inputDecoration(
                    hint: hint,
                    prefixIcon: prefixIcon,
                    suffixIcon: suffixIcon,
                    onSuffixTap: onSuffixTap,
                  ),
                  onSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8.0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: Container(
                      width: constraints.maxWidth,
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Text(
                                option,
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF101828),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
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
                child: _buildAutocompleteField(
                  controller: _pickupControllers[i],
                  focusNode: _pickupFocusNodes[i],
                  hint: i == 0 ? 'City, State' : 'Additional pickup ${i + 1}',
                  prefixIcon: Icons.location_on,
                  suffixIcon: Icons.my_location,
                  onSuffixTap: () => _getLocationFor(_pickupControllers[i]),
                  optionsBuilder:
                      PredictionService.instance.getLocationSuggestions,
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
                child: _buildAutocompleteField(
                  controller: _deliveryControllers[i],
                  focusNode: _deliveryFocusNodes[i],
                  textCapitalization: TextCapitalization.words,
                  hint: i == 0 ? 'City, State' : 'Additional delivery ${i + 1}',
                  prefixIcon: Icons.location_on,
                  suffixIcon: Icons.my_location,
                  onSuffixTap: () => _getLocationFor(_deliveryControllers[i]),
                  optionsBuilder:
                      PredictionService.instance.getLocationSuggestions,
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
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}, $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _getLocationFor(TextEditingController controller) async {
    try {
      double? latitude;
      double? longitude;

      // Try geolocation first
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          try {
            final Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            latitude = position.latitude;
            longitude = position.longitude;
          } catch (e) {
            debugPrint('Geolocation failed: $e');
          }
        }
      }

      // Fallback to IP-based location on web or if geolocation failed
      if (latitude == null || longitude == null) {
        final coords = await _getLocationFromIp();
        if (coords != null) {
          latitude = coords['lat'];
          longitude = coords['lon'];
        }
      }

      // Show error if all methods failed
      if (latitude == null || longitude == null) {
        if (mounted) {
          AppDialogs.showWarning(
            context,
            'Unable to get location. Please enter manually.',
          );
        }
        return;
      }

      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final Placemark place = placemarks[0];
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

  Future<Map<String, double>?> _getLocationFromIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          return {'lat': lat, 'lon': lon};
        }
      }
    } catch (e) {
      debugPrint('IP geolocation failed: $e');
    }
    return null;
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
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/dashboard');
                                  }
                                },
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Truck Number'),
                          const SizedBox(height: 8),
                          _buildAutocompleteField(
                            controller: _tripTruckNumberController,
                            focusNode: _tripTruckFocusNode,
                            textCapitalization: TextCapitalization.characters,
                            hint: 'e.g., T-101',
                            prefixIcon: Icons.local_shipping,
                            optionsBuilder:
                                PredictionService.instance.getTruckSuggestions,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                _buildLabel('Trailer Number'),
                const SizedBox(height: 8),
                ..._buildTrailerFields(),
                const SizedBox(height: 16),
                _buildLabel('Border Crossing (Optional)'),
                const SizedBox(height: 8),
                _buildBorderCrossingDropdown(),
                const SizedBox(height: 16),

                // Trailers section restored above
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
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
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
                    onPressed: _isSaving ? null : _validateAndSaveTrip,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.0,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Update' : 'Save',
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
      AppDialogs.showWarning(context, 'Please enter trip number');
      return;
    }

    // Check truck number
    if (_tripTruckNumberController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter truck number');
      return;
    }

    // Check start odometer
    if (_tripStartOdometerController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter start odometer');
      return;
    }

    // Check if all pickup locations are filled
    for (int i = 0; i < _pickupControllers.length; i++) {
      if (_pickupControllers[i].text.trim().isEmpty) {
        AppDialogs.showWarning(
          context,
          _pickupControllers.length > 1
              ? 'Please fill pickup location ${i + 1} or remove it'
              : 'Please enter pickup location',
        );
        return;
      }
    }

    // Check if all delivery locations are filled
    for (int i = 0; i < _deliveryControllers.length; i++) {
      if (_deliveryControllers[i].text.trim().isEmpty) {
        AppDialogs.showWarning(
          context,
          _deliveryControllers.length > 1
              ? 'Please fill delivery location ${i + 1} or remove it'
              : 'Please enter delivery location',
        );
        return;
      }
    }

    // All validations passed - save the trip
    _saveTrip();
  }

  Future<void> _saveTrip() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Parse date from controller
      DateTime tripDate;
      try {
        tripDate = _parseDateTime(_tripDateController.text);
      } catch (e) {
        tripDate = DateTime.now();
      }

      // Collect pickup locations
      final pickupLocations = _pickupControllers
          .map((c) => c.text.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Collect delivery locations
      final deliveryLocations = _deliveryControllers
          .map((c) => c.text.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Parse odometer values
      final startOdometer = double.tryParse(
        _tripStartOdometerController.text.trim(),
      );
      final endOdometer = _tripEndOdometerController.text.trim().isNotEmpty
          ? double.tryParse(_tripEndOdometerController.text.trim())
          : null;

      final trip = Trip(
        id: widget.editingTrip?.id,
        tripNumber: _tripNumberController.text.trim().toUpperCase(),
        truckNumber: _tripTruckNumberController.text.trim().toUpperCase(),
        borderCrossing: _borderCrossingController.text.trim().isNotEmpty
            ? _borderCrossingController.text.trim()
            : null,
        trailers: _trailerControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        tripDate: tripDate,
        pickupLocations: pickupLocations,
        deliveryLocations: deliveryLocations,
        startOdometer: startOdometer,
        endOdometer: endOdometer,
        distanceUnit: _distanceUnit,
        notes: _tripNotesController.text.trim().isNotEmpty
            ? _tripNotesController.text.trim()
            : null,
      );

      if (_isEditMode && widget.editingTrip != null) {
        await TripService.updateTrip(trip);
      } else {
        // Get existing trips before creating new one
        final existingTrips = await TripService.getTrips();

        // Create the new trip
        await TripService.createTrip(trip);

        // Check if previous trip (before this one) is missing end odometer
        if (existingTrips.isNotEmpty) {
          // Sort by date to get the most recent trip
          existingTrips.sort((a, b) => b.tripDate.compareTo(a.tripDate));
          final previousTrip = existingTrips.first;

          debugPrint(
            '🔔 Previous trip: ${previousTrip.tripNumber}, endOdo: ${previousTrip.endOdometer}',
          );

          if (previousTrip.endOdometer == null) {
            debugPrint(
              '🔔 Previous trip missing end odometer - creating notification',
            );
            await NotificationService.instance.addMissingOdometerReminder(
              tripNumber: previousTrip.tripNumber,
              truckNumber: previousTrip.truckNumber,
            );
          }
        }
      }

      if (mounted) {
        AppDialogs.showSuccess(
          context,
          _isEditMode
              ? 'Trip updated successfully!'
              : 'Trip saved successfully!',
        );
        // Navigate to dashboard after saving
        // Use a small delay to ensure dialog is shown before navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final message = ErrorHandler.getErrorMessage(e);
        AppDialogs.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  DateTime _parseDateTime(String text) {
    // Format: "Dec 3, 2025, 10:30 AM"
    final parts = text.split(', ');
    if (parts.length >= 3) {
      final monthDay = parts[0].split(' ');
      final month = _monthToInt(monthDay[0]);
      final day = int.parse(monthDay[1]);
      final year = int.parse(parts[1]);

      final timeParts = parts[2].split(' ');
      final hourMin = timeParts[0].split(':');
      int hour = int.parse(hourMin[0]);
      final minute = int.parse(hourMin[1]);
      final isPm = timeParts[1].toUpperCase() == 'PM';

      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    }
    return DateTime.now();
  }

  int _monthToInt(String month) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return months[month] ?? 1;
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
                _buildLabel(_isReeferFuel ? 'Reefer Number' : 'Truck Number'),
                const SizedBox(height: 8),
                _buildAutocompleteField(
                  controller: _truckNumberController,
                  focusNode: _truckFocusNode,
                  textCapitalization: TextCapitalization.characters,
                  hint: _isReeferFuel ? 'e.g., R-101' : 'e.g., T-101',
                  prefixIcon: _isReeferFuel
                      ? Icons.ac_unit
                      : Icons.local_shipping,
                  optionsBuilder:
                      PredictionService.instance.getTruckSuggestions,
                ),
                const SizedBox(height: 16),
                // Fuel Type Selector
                _buildLabel('Fuel Type'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isReeferFuel = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !_isReeferFuel
                                  ? const Color(0xFF007AFF)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(11),
                                bottomLeft: Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_gas_station,
                                  size: 20,
                                  color: !_isReeferFuel
                                      ? Colors.white
                                      : Theme.of(context).brightness ==
                                            Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Truck Fuel',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: !_isReeferFuel
                                        ? Colors.white
                                        : Theme.of(context).brightness ==
                                              Brightness.dark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isReeferFuel = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isReeferFuel
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(11),
                                bottomRight: Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.ac_unit,
                                  size: 20,
                                  color: _isReeferFuel
                                      ? Colors.white
                                      : Theme.of(context).brightness ==
                                            Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reefer Fuel',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isReeferFuel
                                        ? Colors.white
                                        : Theme.of(context).brightness ==
                                              Brightness.dark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel(_isReeferFuel ? 'Fuel Location' : 'Location'),
                const SizedBox(height: 8),
                _buildAutocompleteField(
                  controller: _locationController,
                  focusNode: _locationFocusNode,
                  textCapitalization: TextCapitalization.words,
                  hint: _isReeferFuel
                      ? 'Reefer fuel station'
                      : 'Gas station or city',
                  prefixIcon: Icons.location_on,
                  suffixIcon: Icons.my_location,
                  onSuffixTap: () => _getLocationFor(_locationController),
                  optionsBuilder:
                      PredictionService.instance.getLocationSuggestions,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(
                            _isReeferFuel ? 'Reefer Hours' : 'Odometer Reading',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _odometerController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              hint: _isReeferFuel
                                  ? 'Current hours'
                                  : 'Current $_distanceUnit',
                              prefixIcon: _isReeferFuel
                                  ? Icons.timer
                                  : Icons.speed,
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
                          _buildLabel('Currency'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: _inputDecoration(
                              hint: 'Select',
                              prefixIcon: Icons.attach_money,
                            ),
                            dropdownColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                            items: [
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text(
                                  'USD (\$)',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'CAD',
                                child: Text(
                                  'CAD (C\$)',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null && value != _currency) {
                                setState(() {
                                  _currency = value;
                                  if (value == 'USD') {
                                    _fuelUnit = 'gal';
                                    _distanceUnit = 'mi';
                                  } else if (value == 'CAD') {
                                    _fuelUnit = 'L';
                                    _distanceUnit = 'km';
                                  }
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(
                            _isReeferFuel
                                ? 'Reefer Qty ($_fuelUnit)'
                                : 'Fuel Quantity ($_fuelUnit)',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fuelQuantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              hint: '0.0',
                              prefixIcon: _isReeferFuel
                                  ? Icons.ac_unit
                                  : Icons.local_gas_station,
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
                          _buildLabel(
                            'Price (${UnitUtils.getCurrencySymbol(_currency)}/$_fuelUnit)',
                          ),
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
                // [NEW] DEF Section - Only for Truck
                if (!_isReeferFuel) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('DEF Quantity ($_fuelUnit)'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _defQuantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                hint: '0.0',
                                prefixIcon: Icons.water_drop,
                              ),
                              onChanged: (val) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(
                              'DEF Price (${UnitUtils.getCurrencySymbol(_currency)}/$_fuelUnit)',
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _defPriceController,
                              enabled: !_defFromYard, // Disable if from yard
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration:
                                  _inputDecoration(
                                    hint: '0.00',
                                    prefixIcon: Icons.attach_money,
                                  ).copyWith(
                                    fillColor: _defFromYard
                                        ? (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.black38
                                              : Colors.grey.shade200)
                                        : null,
                                  ),
                              onChanged: (val) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'DEF from Yard',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Filled at home terminal (no cost)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    value: _defFromYard,
                    onChanged: (val) {
                      setState(() {
                        _defFromYard = val;
                        if (val) {
                          _defPriceController.clear();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: const Color(0xFF007AFF),
                  ),
                ],
                const SizedBox(height: 16),
                // Show total cost preview
                if (_fuelQuantityController.text.isNotEmpty &&
                    _fuelPriceController.text.isNotEmpty)
                  _buildTotalCostPreview(),
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
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
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
                    onPressed: _isSaving ? null : _validateAndSaveFuel,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.0,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Update' : 'Save',
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

  void _validateAndSaveFuel() {
    // Check date
    if (_fuelDateController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please select date and time');
      return;
    }

    // Check truck/reefer number
    if (_truckNumberController.text.trim().isEmpty) {
      AppDialogs.showWarning(
        context,
        _isReeferFuel
            ? 'Please enter reefer number'
            : 'Please enter truck number',
      );
      return;
    }

    // Check quantities (must have either fuel OR DEF)
    final hasFuel = _fuelQuantityController.text.trim().isNotEmpty;
    final hasDef =
        !_isReeferFuel &&
        _defQuantityController.text.trim().isNotEmpty &&
        (double.tryParse(_defQuantityController.text.trim()) ?? 0) > 0;

    if (!hasFuel && !hasDef) {
      AppDialogs.showWarning(
        context,
        _isReeferFuel
            ? 'Please enter fuel quantity'
            : 'Please enter fuel or DEF quantity',
      );
      return;
    }

    // If fuel is entered, check price (unless price is 0 which can be valid?)
    // Actually user says "if user want to fill only DEF".
    // So if hasFuel is true, we should check fuel price.
    if (hasFuel && _fuelPriceController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter fuel price');
      return;
    }

    // All validations passed - save the fuel entry
    _saveFuel();
  }

  Future<void> _saveFuel() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Parse date from controller
      DateTime fuelDate;
      try {
        fuelDate = _parseDateTime(_fuelDateController.text);
      } catch (e) {
        fuelDate = DateTime.now();
      }

      // Parse values
      final fuelQuantity =
          double.tryParse(_fuelQuantityController.text.trim()) ?? 0;
      final pricePerUnit =
          double.tryParse(_fuelPriceController.text.trim()) ?? 0;
      final odometerReading = _odometerController.text.trim().isNotEmpty
          ? double.tryParse(_odometerController.text.trim())
          : null;

      // Parse DEF values
      double defQuantity = 0;
      double defPrice = 0;
      if (!_isReeferFuel) {
        defQuantity = double.tryParse(_defQuantityController.text.trim()) ?? 0;
        // If from yard, price is 0
        defPrice = _defFromYard
            ? 0
            : (double.tryParse(_defPriceController.text.trim()) ?? 0);
      }

      final fuelEntry = FuelEntry(
        id: widget.editingFuel?.id,
        fuelDate: fuelDate,
        fuelType: _isReeferFuel ? 'reefer' : 'truck',
        truckNumber: !_isReeferFuel
            ? _truckNumberController.text.trim().toUpperCase()
            : null,
        reeferNumber: _isReeferFuel
            ? _truckNumberController.text.trim().toUpperCase()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        odometerReading: !_isReeferFuel ? odometerReading : null,
        reeferHours: _isReeferFuel ? odometerReading : null,
        fuelQuantity: fuelQuantity,
        pricePerUnit: pricePerUnit,
        fuelUnit: _fuelUnit,
        distanceUnit: _distanceUnit,
        currency: _currency,
        defQuantity: defQuantity,
        defPrice: defPrice,
        defFromYard: _defFromYard,
      );

      if (_isEditMode && widget.editingFuel != null) {
        await FuelService.updateFuelEntry(fuelEntry);
      } else {
        await FuelService.createFuelEntry(fuelEntry);
      }

      if (mounted) {
        AppDialogs.showSuccess(
          context,
          _isEditMode
              ? 'Fuel entry updated successfully!'
              : 'Fuel entry saved successfully!',
        );
        // Navigate to dashboard after saving
        // Use a small delay to ensure dialog is shown before navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final message = ErrorHandler.getErrorMessage(e);
        AppDialogs.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

  Widget _buildTotalCostPreview() {
    final quantity = double.tryParse(_fuelQuantityController.text.trim()) ?? 0;
    final price = double.tryParse(_fuelPriceController.text.trim()) ?? 0;
    final total = quantity * price;

    double defTotal = 0;
    if (!_isReeferFuel) {
      final defQty = double.tryParse(_defQuantityController.text.trim()) ?? 0;
      final defPrc = double.tryParse(_defPriceController.text.trim()) ?? 0;
      defTotal = defQty * defPrc;
    }

    final grandTotal = total + defTotal;

    final currencySymbol = UnitUtils.getCurrencySymbol(_currency);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Cost',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currencySymbol${grandTotal.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${quantity.toStringAsFixed(1)} $_fuelUnit',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              Text(
                '@ $currencySymbol${price.toStringAsFixed(3)}/$_fuelUnit',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              if (!_isReeferFuel &&
                  (_defQuantityController.text.isNotEmpty &&
                      (double.tryParse(_defQuantityController.text) ?? 0) >
                          0)) ...[
                const SizedBox(height: 4),
                Text(
                  '+ DEF: ${double.parse(_defQuantityController.text).toStringAsFixed(1)} $_fuelUnit',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (!_defFromYard)
                  Text(
                    '@ $currencySymbol${(double.tryParse(_defPriceController.text) ?? 0).toStringAsFixed(3)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF667085),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    '(Yard)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Methods to manage trailers
  void _addTrailer([String? customTrailer]) {
    if (_trailerControllers.length < _maxTrailers) {
      setState(() {
        _trailerControllers.add(TextEditingController(text: customTrailer));
        _trailerFocusNodes.add(FocusNode());
      });
    }
  }

  void _removeTrailer(int index) {
    if (_trailerControllers.length > 1) {
      setState(() {
        _trailerControllers[index].dispose();
        _trailerControllers.removeAt(index);
        _trailerFocusNodes[index].dispose();
        _trailerFocusNodes.removeAt(index);
      });
    }
  }

  List<Widget> _buildTrailerFields() {
    final fields = <Widget>[];
    for (int i = 0; i < _trailerControllers.length; i++) {
      final isLast = i == _trailerControllers.length - 1;
      final canAdd = _trailerControllers.length < _maxTrailers;
      final canRemove = _trailerControllers.length > 1;

      fields.add(
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trailerControllers[i],
                  focusNode: _trailerFocusNodes[i],
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    hint: 'e.g., 5301',
                    prefixIcon: Icons.grid_3x3,
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _removeTrailer(i),
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
                    onTap: () => _addTrailer(),
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
}
