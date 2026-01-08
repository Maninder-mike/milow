import 'package:flutter/material.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/utils/error_handler.dart';
import 'package:milow_core/milow_core.dart'; // VehicleRepository, Trip, FuelEntry

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/profile_service.dart';
import 'package:milow/core/services/trip_service.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/fuel_repository.dart';
import 'package:milow/core/services/data_prefetch_service.dart';
import 'package:milow/core/services/notification_service.dart';
// import 'package:milow_core/milow_core.dart'; // Already imported above
import 'package:milow/core/utils/unit_utils.dart';
import 'package:milow/core/services/prediction_service.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

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

  // Scroll-to-hide header disabled per user request
  final ScrollController _tripScrollController = ScrollController();
  final ScrollController _fuelScrollController = ScrollController();

  // Unit system
  String _distanceUnit = 'mi';
  String _fuelUnit = 'gal';
  String _currency = 'USD';
  bool _isReeferFuel = false;
  bool _defFromYard = false; // [NEW] DEF from Yard toggle
  bool _isEmptyLeg = false; // [NEW] Empty Leg toggle
  bool _isSaving = false;

  // Duplicate trip number validation
  bool _tripNumberExists = false;
  List<String> _existingTripNumbers = [];

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
  final List<DateTime?> _pickupTimes = []; // [NEW]
  final List<bool> _pickupCompleted = []; // [NEW]
  final List<DateTime?> _deliveryTimes = []; // [NEW]
  final List<bool> _deliveryCompleted = []; // [NEW]
  final _truckFocusNode = FocusNode(); // For Fuel
  final _locationFocusNode = FocusNode(); // For Fuel

  // Vehicles
  List<Vehicle> _vehicles = [];

  String? _selectedTripVehicleId;
  String? _selectedFuelVehicleId;
  bool _isLoadingVehicles = false;

  // State for fetched trip (either passed in or fetched dynamically)
  Trip? _fetchedTrip;

  @override
  void initState() {
    super.initState();
    _fetchedTrip = widget.editingTrip;
    // ... rest of initState
    _loadVehicles();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.editingFuel != null ? 1 : widget.initialTab,
    );

    // Initialize header animation
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: M3ExpressiveMotion.durationMedium,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: M3ExpressiveMotion.decelerated,
      reverseCurve: M3ExpressiveMotion.accelerated,
    );
    _headerAnimationController.value = 1.0; // Start visible

    // _tripScrollController.addListener(_onTripScroll);
    // _fuelScrollController.addListener(_onFuelScroll);
    _loadUnitPreferences();
    _prefillBorderCrossing();

    // Add listeners for total cost preview
    _fuelQuantityController.addListener(_onFuelFieldChanged);
    _fuelPriceController.addListener(_onFuelFieldChanged);
    _defQuantityController.addListener(_onFuelFieldChanged); // [NEW]
    _defPriceController.addListener(_onFuelFieldChanged); // [NEW]

    // Add listener for real-time trip number duplicate validation
    _tripNumberController.addListener(_checkTripNumberExists);
    _loadExistingTripNumbers();

    // Initialize with one pickup, one delivery, and one trailer (without setState)
    _pickupControllers.add(TextEditingController());
    _pickupFocusNodes.add(FocusNode());
    _deliveryControllers.add(TextEditingController());
    _deliveryFocusNodes.add(FocusNode());
    _trailerControllers.add(TextEditingController());
    _trailerFocusNodes.add(FocusNode());

    // Initialize new lists
    _pickupTimes.add(null);
    _pickupCompleted.add(false);
    _deliveryTimes.add(null);
    _deliveryCompleted.add(false);

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

  Future<void> _loadVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final vehicles = await VehicleRepository.getVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load vehicles: $e');
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  void _prefillTripData(Trip trip) {
    _tripNumberController.text = trip.tripNumber;
    _tripTruckNumberController.text = trip.truckNumber;
    _selectedTripVehicleId = trip.vehicleId;
    if (_selectedTripVehicleId == null && _vehicles.isNotEmpty) {
      final v = _vehicles.cast<Vehicle?>().firstWhere(
        (v) => v?.truckNumber == trip.truckNumber,
        orElse: () => null,
      );
      if (v != null) _selectedTripVehicleId = v.id;
    }

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

    // Fill pickup times and completion
    if (trip.pickupTimes.isNotEmpty) {
      // Clear and re-populate to match locations
      if (_pickupTimes.isNotEmpty) {
        _pickupTimes.clear();
        _pickupCompleted.clear();
      }
      for (var i = 0; i < trip.pickupTimes.length; i++) {
        _pickupTimes.add(trip.pickupTimes[i]);
        // Handle matching completed list length safety
        if (i < trip.pickupCompleted.length) {
          _pickupCompleted.add(trip.pickupCompleted[i]);
        } else {
          _pickupCompleted.add(false);
        }
      }
      // Ensure length matches controllers if possible (padding)
      while (_pickupTimes.length < _pickupControllers.length) {
        _pickupTimes.add(null);
        _pickupCompleted.add(false);
      }
    }

    // Fill delivery times and completion
    if (trip.deliveryTimes.isNotEmpty) {
      if (_deliveryTimes.isNotEmpty) {
        _deliveryTimes.clear();
        _deliveryCompleted.clear();
      }
      for (var i = 0; i < trip.deliveryTimes.length; i++) {
        _deliveryTimes.add(trip.deliveryTimes[i]);
        if (i < trip.deliveryCompleted.length) {
          _deliveryCompleted.add(trip.deliveryCompleted[i]);
        } else {
          _deliveryCompleted.add(false);
        }
      }
      while (_deliveryTimes.length < _deliveryControllers.length) {
        _deliveryTimes.add(null);
        _deliveryCompleted.add(false);
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
    _isEmptyLeg = trip.isEmptyLeg;
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
    _selectedFuelVehicleId = fuel.vehicleId;
    // Fallback: match by number
    if (_selectedFuelVehicleId == null &&
        _vehicles.isNotEmpty &&
        _truckNumberController.text.isNotEmpty) {
      final v = _vehicles.cast<Vehicle?>().firstWhere(
        (v) => v?.truckNumber == _truckNumberController.text,
        orElse: () => null,
      );
      if (v != null) _selectedFuelVehicleId = v.id;
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
    final prefDistanceUnit = await PreferencesService.getDistanceUnit();
    final prefFuelUnit = await PreferencesService.getVolumeUnit();

    // Get currency from user profile country
    final profile = await ProfileService.getProfile();
    final country = profile?['country'] as String?;
    final prefCurrency = UnitUtils.getCurrency(country);

    if (mounted) {
      setState(() {
        if (!_isEditMode) {
          // New Entry: Sync units based on currency (not global preferences)
          // USD → Imperial (gal, mi), CAD → Metric (L, km)
          _currency = prefCurrency;
          if (prefCurrency == 'USD') {
            _fuelUnit = 'gal';
            _distanceUnit = 'mi';
          } else if (prefCurrency == 'CAD') {
            _fuelUnit = 'L';
            _distanceUnit = 'km';
          } else {
            // Fallback to preferences for other currencies
            _distanceUnit = prefDistanceUnit;
            _fuelUnit = prefFuelUnit;
          }
        } else {
          // Edit Mode: Convert units if they differ from preference
          // Preserve currency for historical accuracy

          // 1. Convert Distance (mi <-> km)
          if (_distanceUnit != prefDistanceUnit) {
            final toMetric = prefDistanceUnit == 'km';
            final factor = toMetric ? 1.60934 : 0.621371;

            // Helper to convert text field
            void convertField(TextEditingController controller) {
              final val = double.tryParse(controller.text.replaceAll(',', ''));
              if (val != null) {
                final newVal = val * factor;
                // Odometer usually int or 1 decimal
                controller.text = newVal.toStringAsFixed(toMetric ? 1 : 0);
              }
            }

            convertField(_tripStartOdometerController);
            convertField(_tripEndOdometerController);
            convertField(_odometerController); // For fuel entry

            _distanceUnit = prefDistanceUnit;
          }

          // 2. Convert Volume (gal <-> L)
          // Note: Fuel Price is also per unit, so it must be inverted/converted
          if (_fuelUnit != prefFuelUnit) {
            final toMetric = prefFuelUnit == 'L';
            // 1 gal = 3.78541 L
            final volumeFactor = toMetric ? 3.78541 : 0.264172;

            // Price is currency/volume. So if volume increases (gal->L), price decreases.
            // $/gal -> $/L. 1 gal = 3.78 L.
            // $4/gal = $4 / 3.78 L = $1.05/L.
            // So price factor is 1/volumeFactor.
            final priceFactor = 1 / volumeFactor;

            void convertVolume(TextEditingController controller) {
              final val = double.tryParse(controller.text.replaceAll(',', ''));
              if (val != null) {
                controller.text = (val * volumeFactor).toStringAsFixed(2);
              }
            }

            void convertPrice(TextEditingController controller) {
              final val = double.tryParse(controller.text.replaceAll(',', ''));
              if (val != null) {
                controller.text = (val * priceFactor).toStringAsFixed(3);
              }
            }

            convertVolume(_fuelQuantityController);
            convertPrice(_fuelPriceController);

            convertVolume(_defQuantityController);
            convertPrice(_defPriceController);

            _fuelUnit = prefFuelUnit;
          }
        }
      });
    }
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
    final tokens = context.tokens;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Border Crossing',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g., Windsor-Detroit',
            filled: true,
            fillColor: tokens.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: tokens.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: tokens.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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

  /// Load all existing trip numbers for duplicate detection
  Future<void> _loadExistingTripNumbers() async {
    try {
      final trips = await TripRepository.getTrips(refresh: false);
      if (mounted) {
        setState(() {
          _existingTripNumbers = trips
              .where(
                (t) => t.id != widget.editingTrip?.id,
              ) // Exclude current trip in edit mode
              .map((t) => t.tripNumber.toUpperCase())
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load existing trip numbers: $e');
    }
  }

  /// Check if the entered trip number already exists (real-time validation)
  void _checkTripNumberExists() {
    final tripNumber = _tripNumberController.text.trim().toUpperCase();
    final exists =
        tripNumber.isNotEmpty && _existingTripNumbers.contains(tripNumber);
    if (exists != _tripNumberExists) {
      setState(() => _tripNumberExists = exists);
    }
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    // _tripScrollController.removeListener(_onTripScroll);
    // _fuelScrollController.removeListener(_onFuelScroll);
    _fuelQuantityController.removeListener(_onFuelFieldChanged);
    _fuelPriceController.removeListener(_onFuelFieldChanged);
    _defQuantityController.removeListener(_onFuelFieldChanged); // [NEW]
    _defPriceController.removeListener(_onFuelFieldChanged); // [NEW]
    _tripNumberController.removeListener(_checkTripNumberExists);
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
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<String>(
                width: constraints.maxWidth,
                initialSelection: _selectedBorderCrossing,
                label: const Text('Border Crossing'),
                leadingIcon: Icon(
                  Icons.flag_rounded,
                  color: tokens.textTertiary,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: tokens.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                    borderSide: BorderSide(color: tokens.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                    borderSide: BorderSide(color: tokens.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                dropdownMenuEntries: _borderCrossings.map((border) {
                  return DropdownMenuEntry<String>(
                    value: border,
                    label: border,
                    leadingIcon: Icon(
                      Icons.flag_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  );
                }).toList(),
                onSelected: (value) {
                  setState(() {
                    _selectedBorderCrossing = value;
                    _borderCrossingController.text = value ?? '';
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _showAddBorderCrossingDialog,
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeM),
            ),
            fixedSize: const Size(56, 56),
          ),
          tooltip: 'Add Border Crossing',
        ),
      ],
    );
  }

  // [NEW] Quick Actions Section (Capsules)
  Widget _buildQuickActions() {
    final hasPickups =
        _pickupControllers.isNotEmpty &&
        _pickupControllers.any((c) => c.text.isNotEmpty);

    final hasDeliveries =
        _deliveryControllers.isNotEmpty &&
        _deliveryControllers.any((c) => c.text.isNotEmpty);

    // Hide if no data entered (e.g. fresh form)
    if (!hasPickups && !hasDeliveries) return const SizedBox.shrink();

    final actions = <Widget>[];

    if (hasPickups) {
      // Pickup Mode Actions
      if (_pickupCompleted.isNotEmpty) {
        final isPickedUp = _pickupCompleted[0];
        actions.add(
          FilterChip(
            selected: isPickedUp,
            showCheckmark: false,
            label: Text(
              isPickedUp ? 'Picked Up' : 'Picked Up Load',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isPickedUp
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            avatar: Icon(
              isPickedUp ? Icons.check_circle : Icons.check_circle_outline,
              size: 18,
              color: isPickedUp
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary,
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            selectedColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(
              color: isPickedUp
                  ? Colors.transparent
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (selected) {
              setState(() {
                _pickupCompleted[0] = selected;
              });
              if (selected) {
                // If checking "Picked Up", validation or snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Marked as Picked Up. Save to persist.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
          ),
        );
      }

      if (_pickupTimes.isNotEmpty) {
        final hasTime = _pickupTimes[0] != null;
        actions.add(
          FilterChip(
            selected: hasTime,
            showCheckmark: false,
            label: Text(
              hasTime
                  ? 'Time: ${_formatTime(_pickupTimes[0]!)}'
                  : 'Add Pickup Time',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: hasTime
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.tertiary,
              ),
            ),
            avatar: Icon(
              Icons.access_time_rounded,
              size: 18,
              color: hasTime
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.tertiary,
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
            side: BorderSide(
              color: hasTime
                  ? Colors.transparent
                  : Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (selected) async {
              if (selected) {
                // Pick time if not clearing (FilterChip toggle behavior usually implies 'on' = set)
                // But simplified: tapping always opens time picker to refine/set
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final now = DateTime.now();
                  setState(() {
                    _pickupTimes[0] = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              } else {
                // Clearing time
                setState(() {
                  _pickupTimes[0] = null;
                });
              }
            },
          ),
        );
      }
    }

    if (hasDeliveries) {
      // Delivery Mode Actions
      if (_deliveryCompleted.isNotEmpty) {
        actions.add(
          FilterChip(
            selected: _deliveryCompleted[0],
            showCheckmark: false,
            label: Text(
              _deliveryCompleted[0] ? 'Delivered' : 'Delivery Done',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _deliveryCompleted[0]
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.tokens.textPrimary,
              ),
            ),
            avatar: Icon(
              _deliveryCompleted[0]
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              size: 18,
              color: _deliveryCompleted[0]
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary,
            ),
            backgroundColor: context.tokens.surfaceContainer,
            selectedColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(
              color: _deliveryCompleted[0]
                  ? Colors.transparent
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (selected) {
              setState(() {
                _deliveryCompleted[0] = selected;
              });
            },
          ),
        );
      }

      if (_deliveryTimes.isNotEmpty) {
        final hasTime = _deliveryTimes[0] != null;
        actions.add(
          FilterChip(
            selected: hasTime,
            showCheckmark: false,
            label: Text(
              hasTime
                  ? 'Time: ${_formatTime(_deliveryTimes[0]!)}'
                  : 'Add Delivery Time',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: hasTime
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : context.tokens.textPrimary,
              ),
            ),
            avatar: Icon(
              Icons.access_time_rounded,
              size: 18,
              color: hasTime
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.tertiary,
            ),
            backgroundColor: context.tokens.surfaceContainer,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
            side: BorderSide(
              color: hasTime
                  ? Colors.transparent
                  : Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (selected) async {
              if (selected) {
                // Set to now, or pick time
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final now = DateTime.now();
                  setState(() {
                    _deliveryTimes[0] = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              } else {
                setState(() {
                  _deliveryTimes[0] = null;
                });
              }
            },
          ),
        );
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: actions
              .map(
                (w) =>
                    Padding(padding: const EdgeInsets.only(right: 8), child: w),
              )
              .toList(),
        ),
      ),
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
                child: CustomAutocompleteField(
                  controller: _pickupControllers[i],
                  focusNode: _pickupFocusNodes[i],
                  label: i == 0 ? 'Pickup Location' : 'Pickup ${i + 1}',
                  hint: i == 0 ? 'City, State' : 'City, State',
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
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
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
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: Theme.of(context).colorScheme.tertiary,
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
                child: CustomAutocompleteField(
                  controller: _deliveryControllers[i],
                  focusNode: _deliveryFocusNodes[i],
                  textCapitalization: TextCapitalization.words,
                  label: i == 0 ? 'Delivery Location' : 'Delivery ${i + 1}',
                  hint: i == 0 ? 'City, State' : 'City, State',
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
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
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
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: Theme.of(context).colorScheme.tertiary,
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

  // void _onTripScroll() {
  //   _handleScroll(_tripScrollController);
  // }

  // void _onFuelScroll() {
  //   _handleScroll(_fuelScrollController);
  // }

  // void _handleScroll(ScrollController controller) {
  //   // Disabled header hiding on scroll per user request
  // }

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

  // [NEW] Fetch trip wrapper logic
  void _fetchTripRecord(String tripNumber) async {
    if (tripNumber.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final trips = await TripRepository.searchTrips(tripNumber);
      final match = trips.where((t) => t.tripNumber == tripNumber).firstOrNull;

      if (mounted) {
        setState(() => _isSaving = false);
        if (match != null) {
          _fetchedTrip = match;
          _prefillTripData(match);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded trip ${match.tripNumber}')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Trip not found')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      debugPrint('Error fetching trip: $e');
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

  Future<void> _fetchLastDestination() async {
    try {
      // Get the most recent trip
      final recentTrips = await TripService.getTrips(limit: 1);

      if (recentTrips.isNotEmpty && mounted) {
        final lastTrip = recentTrips.first;

        if (lastTrip.deliveryLocations.isNotEmpty) {
          final lastDestination = lastTrip.deliveryLocations.last;

          if (lastDestination.isNotEmpty) {
            setState(() {
              // Assuming the first pickup location is where we want to prefill
              if (_pickupControllers.isNotEmpty) {
                _pickupControllers[0].text = lastDestination;
              } else {
                // Should exist by default, but just in case
                _addPickupLocation();
                _pickupControllers[0].text = lastDestination;
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Prefilled pickup location from last trip: $lastDestination',
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            );
          }
        }

        // Autofill Truck Number
        if (lastTrip.truckNumber.isNotEmpty) {
          setState(() {
            _tripTruckNumberController.text = lastTrip.truckNumber;
          });
        }

        // Autofill Trailers
        if (lastTrip.trailers.isNotEmpty) {
          setState(() {
            // Clear existing trailers
            for (var controller in _trailerControllers) {
              controller.dispose();
            }
            _trailerControllers.clear();
            for (var node in _trailerFocusNodes) {
              node.dispose();
            }
            _trailerFocusNodes.clear();

            // Add trailers from last trip
            for (var trailer in lastTrip.trailers) {
              _addTrailer(trailer);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch last destination: $e');
      // Fail silently or show subtle error
    }
  }

  Future<Iterable<String>> _getVehicleSuggestions(
    String query, {
    String? filter,
  }) async {
    if (query.isEmpty) return const Iterable<String>.empty();
    final lowercaseQuery = query.toLowerCase();

    return _vehicles
        .where((v) {
          if (filter != null) {
            final type = v.vehicleType?.toLowerCase();
            // If filter is provided, key off match.
            // Special handling for 'reefer' which includes trailers
            if (filter == 'reefer') {
              if (type != 'reefer' && type != 'trailer') return false;
            } else if (type != null && type != filter) {
              return false;
            }
          }
          return v.truckNumber.toLowerCase().contains(lowercaseQuery);
        })
        .map((v) => v.truckNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: 20,
                                ),
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
                                    _fetchedTrip != null ||
                                            widget.editingTrip != null
                                        ? 'Edit Entry'
                                        : 'Add Entry',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Track trips and fuel',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Fetch Trip Logic
                              IconButton(
                                onPressed: () {
                                  if (_tripNumberController.text.isNotEmpty) {
                                    _fetchTripRecord(
                                      _tripNumberController.text,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Enter trip number to fetch',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Fetch Trip Record',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/dashboard');
                                  }
                                },
                                tooltip: 'Cancel',
                              ),
                              const SizedBox(width: 4),
                              FilledButton(
                                onPressed: _isSaving
                                    ? null
                                    : () {
                                        if (_tabController.index == 0) {
                                          _validateAndSaveTrip();
                                        } else {
                                          _validateAndSaveFuel();
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                  // Style handled by theme
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          strokeCap: StrokeCap.round,
                                        ),
                                      )
                                    : Text(
                                        'Save',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Tabs
                    if (widget.editingTrip == null &&
                        widget.editingFuel == null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          unselectedLabelColor: context.tokens.textSecondary,
                          labelStyle: Theme.of(context).textTheme.labelLarge,
                          unselectedLabelStyle: Theme.of(
                            context,
                          ).textTheme.labelLarge,
                          tabs: const [
                            Tab(text: 'Add Trip'),
                            Tab(text: 'Add Fuel'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics:
                    (widget.editingTrip != null || widget.editingFuel != null)
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [_buildAddTripTab(), _buildAddFuelTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTripTab() {
    return SingleChildScrollView(
      controller: _tripScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Actions for existing trips (Capsules)
          _buildQuickActions(),
          // Empty Leg Toggle - only show for new trips
          if (_fetchedTrip == null && widget.editingTrip == null) ...[
            Container(
              decoration: BoxDecoration(
                color: context.tokens.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.tokens.inputBorder),
              ),
              child: SwitchListTile(
                value: _isEmptyLeg,
                onChanged: (value) {
                  setState(() => _isEmptyLeg = value);
                  if (value) {
                    _fetchLastDestination();
                  }
                },
                title: Text(
                  'Empty Leg',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.tokens.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Driving without cargo (Deadhead)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                secondary: Icon(
                  Icons.no_luggage_outlined,
                  color: _isEmptyLeg
                      ? context.tokens.textPrimary
                      : context.tokens.textTertiary,
                ),
                activeThumbColor: Theme.of(context).colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildSectionCard(
            title: 'Trip Details',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tripNumberController,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.text,
                      decoration:
                          _inputDecoration(
                            label: 'Trip Number',
                            hint: 'e.g., TR-12345',
                            prefixIcon: Icons.tag,
                          ).copyWith(
                            errorText: _tripNumberExists
                                ? 'Trip number already exists'
                                : null,
                            suffixIcon: _tripNumberExists
                                ? Icon(
                                    Icons.error_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  )
                                : null,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomAutocompleteField(
                      controller: _tripTruckNumberController,
                      focusNode: _tripTruckFocusNode,
                      label: 'Truck Number',
                      hint: 'e.g., 101',
                      prefixIcon: Icons.local_shipping,
                      textCapitalization: TextCapitalization.characters,
                      optionsBuilder: (query) =>
                          _getVehicleSuggestions(query, filter: 'truck'),
                      onSelected: (value) {
                        setState(() {
                          final v = _vehicles.cast<Vehicle?>().firstWhere(
                            (v) => v?.truckNumber == value,
                            orElse: () => null,
                          );
                          _selectedTripVehicleId = v?.id;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._buildTrailerFields(),
              const SizedBox(height: 12),

              _buildBorderCrossingDropdown(),
            ],
          ),
          _buildSectionCard(
            title: 'Schedule',
            children: [
              TextField(
                controller: _tripDateController,
                readOnly: true,
                decoration: _inputDecoration(
                  label: 'Date & Time',
                  hint: 'Tap to select',
                  prefixIcon: Icons.calendar_today,
                ),
                onTap: () => _selectDateTime(_tripDateController),
              ),
            ],
          ),
          _buildSectionCard(
            title: 'Route',
            children: [
              ..._buildPickupLocationFields(),
              const SizedBox(height: 12),
              ..._buildDeliveryLocationFields(),
            ],
          ),
          _buildSectionCard(
            title: 'Operations',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tripStartOdometerController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Start Odometer',
                        hint: _distanceUnit,
                        prefixIcon: Icons.speed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tripEndOdometerController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'End Odometer',
                        hint: _distanceUnit,
                        prefixIcon: Icons.speed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tripNotesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                keyboardType: TextInputType.text,
                decoration: _inputDecoration(
                  label: 'Notes',
                  hint: 'Additional details...',
                  prefixIcon: Icons.notes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _validateAndSaveTrip() {
    // Check trip number
    if (_tripNumberController.text.trim().isEmpty) {
      AppDialogs.showWarning(context, 'Please enter trip number');
      return;
    }

    // Check for duplicate trip number (only for new trips)
    if (!_isEditMode && _tripNumberExists) {
      AppDialogs.showWarning(
        context,
        'Trip number already exists. Please use a different number.',
      );
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

      // Parse odometer values
      final startOdometer = double.tryParse(
        _tripStartOdometerController.text.trim(),
      );
      final endOdometer = _tripEndOdometerController.text.trim().isNotEmpty
          ? double.tryParse(_tripEndOdometerController.text.trim())
          : null;

      // [NEW] Resolve Vehicle ID from text input (to handle manual typing or correction)
      final truckText = _tripTruckNumberController.text.trim();
      if (truckText.isNotEmpty && _vehicles.isNotEmpty) {
        final v = _vehicles.cast<Vehicle?>().firstWhere(
          (v) => v?.truckNumber.toLowerCase() == truckText.toLowerCase(),
          orElse: () => null,
        );
        _selectedTripVehicleId = v?.id;
      } else {
        _selectedTripVehicleId = null;
      }

      final trip = Trip(
        id: widget.editingTrip?.id,
        vehicleId: _selectedTripVehicleId,
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
        pickupLocations: _pickupControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map((e) => e.value.text.trim())
            .toList(),
        pickupTimes: _pickupControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map(
              (e) => e.key < _pickupTimes.length ? _pickupTimes[e.key] : null,
            )
            .toList(),
        pickupCompleted: _pickupControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map(
              (e) => e.key < _pickupCompleted.length
                  ? _pickupCompleted[e.key]
                  : false,
            )
            .toList(),
        deliveryLocations: _deliveryControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map((e) => e.value.text.trim())
            .toList(),
        deliveryTimes: _deliveryControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map(
              (e) =>
                  e.key < _deliveryTimes.length ? _deliveryTimes[e.key] : null,
            )
            .toList(),
        deliveryCompleted: _deliveryControllers
            .asMap()
            .entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map(
              (e) => e.key < _deliveryCompleted.length
                  ? _deliveryCompleted[e.key]
                  : false,
            )
            .toList(),
        startOdometer: startOdometer,
        endOdometer: endOdometer,
        distanceUnit: _distanceUnit,
        notes: _tripNotesController.text.trim().isNotEmpty
            ? _tripNotesController.text.trim()
            : null,
        isEmptyLeg: _isEmptyLeg,
      );

      if (_isEditMode && widget.editingTrip != null) {
        await TripRepository.updateTrip(trip);
      } else {
        // Get existing trips before creating new one
        final existingTrips = await TripRepository.getTrips();

        // Create the new trip (offline-first: saves locally, queues sync)
        await TripRepository.createTrip(trip);

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

        // Invalidate dashboard cache so it reloads from repository
        DataPrefetchService.instance.invalidateCache();

        // Navigate to dashboard after saving
        // Use a small delay to ensure dialog is shown before navigation
        if (mounted) {
          context.pop(true);
        }
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

  // Helper for formatting time
  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12;
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  Widget _buildAddFuelTab() {
    return SingleChildScrollView(
      controller: _fuelScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionCard(
            title: 'Fuel Details',
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isReeferFuel = false;
                          _selectedFuelVehicleId = null;
                          _truckNumberController.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: !_isReeferFuel
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_gas_station,
                                size: 20,
                                color: !_isReeferFuel
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : context.tokens.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Truck Fuel',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: !_isReeferFuel
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : context.tokens.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isReeferFuel = true;
                          _selectedFuelVehicleId = null;
                          _truckNumberController.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _isReeferFuel
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.ac_unit,
                                size: 20,
                                color: _isReeferFuel
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : context.tokens.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reefer Fuel',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _isReeferFuel
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : context.tokens.textSecondary,
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
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              CustomAutocompleteField(
                controller: _truckNumberController,
                focusNode: _truckFocusNode,
                label: _isReeferFuel ? 'Reefer Unit' : 'Truck Number',
                hint: _isLoadingVehicles ? 'Loading...' : 'e.g., 101',
                prefixIcon: _isReeferFuel
                    ? Icons.ac_unit
                    : Icons.local_shipping,
                textCapitalization: TextCapitalization.characters,
                optionsBuilder: (query) => _getVehicleSuggestions(
                  query,
                  filter: _isReeferFuel ? 'reefer' : 'truck',
                ),
                onSelected: (value) {
                  setState(() {
                    final v = _vehicles.cast<Vehicle?>().firstWhere(
                      (v) => v?.truckNumber == value,
                      orElse: () => null,
                    );
                    _selectedFuelVehicleId = v?.id;
                  });
                },
              ),
              const SizedBox(height: 12),
              CustomAutocompleteField(
                controller: _locationController,
                focusNode: _locationFocusNode,
                textCapitalization: TextCapitalization.words,
                label: _isReeferFuel ? 'Fuel Location' : 'Location',
                hint: _isReeferFuel ? 'Reefer fuel station' : 'Station or city',
                prefixIcon: Icons.location_on,
                suffixIcon: Icons.my_location,
                onSuffixTap: () => _getLocationFor(_locationController),
                optionsBuilder:
                    PredictionService.instance.getLocationSuggestions,
              ),
            ],
          ),
          _buildSectionCard(
            title: 'Schedule & Metrics',
            children: [
              TextField(
                controller: _fuelDateController,
                readOnly: true,
                decoration: _inputDecoration(
                  label: 'Date & Time',
                  hint: 'Tap to select',
                  prefixIcon: Icons.calendar_today,
                ),
                onTap: () => _selectDateTime(_fuelDateController),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _odometerController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: _isReeferFuel ? 'Hours' : 'Odometer',
                        hint: _isReeferFuel ? 'Hours' : _distanceUnit,
                        prefixIcon: _isReeferFuel ? Icons.timer : Icons.speed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: _inputDecoration(
                        label: 'Currency',
                        hint: 'Select',
                        prefixIcon: Icons.attach_money,
                      ),
                      dropdownColor: Theme.of(context).cardColor,
                      items: [
                        const DropdownMenuItem(
                          value: 'USD',
                          child: Text('USD (\$)'),
                        ),
                        const DropdownMenuItem(
                          value: 'CAD',
                          child: Text('CAD (C\$)'),
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
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            title: 'Quantities',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fuelQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        label: 'Fuel Qty ($_fuelUnit)',
                        hint: '0.0',
                        prefixIcon: _isReeferFuel
                            ? Icons.ac_unit
                            : Icons.local_gas_station,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fuelPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        label: 'Price/$_fuelUnit',
                        hint: '0.00',
                        prefixIcon: Icons.attach_money,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isReeferFuel) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _defQuantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          label: 'DEF Qty ($_fuelUnit)',
                          hint: '0.0',
                          prefixIcon: Icons.water_drop,
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _defPriceController,
                        enabled: !_defFromYard,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            _inputDecoration(
                              label: 'DEF Price/$_fuelUnit',
                              hint: '0.00',
                              prefixIcon: Icons.attach_money,
                            ).copyWith(
                              fillColor: _defFromYard
                                  ? Theme.of(
                                      context,
                                    ).disabledColor.withValues(alpha: 0.1)
                                  : null,
                            ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    'Filled at home terminal (no cost)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  value: _defFromYard,
                  onChanged: (val) {
                    setState(() {
                      _defFromYard = val;
                      if (val) _defPriceController.clear();
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          if (_fuelQuantityController.text.isNotEmpty &&
              _fuelPriceController.text.isNotEmpty)
            _buildTotalCostPreview(),
        ],
      ),
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

      // [NEW] Resolve Vehicle ID from text input
      final truckText = _truckNumberController.text.trim();
      if (truckText.isNotEmpty && _vehicles.isNotEmpty) {
        final v = _vehicles.cast<Vehicle?>().firstWhere(
          (v) => v?.truckNumber.toLowerCase() == truckText.toLowerCase(),
          orElse: () => null,
        );
        _selectedFuelVehicleId = v?.id;
      } else {
        _selectedFuelVehicleId = null;
      }

      final fuelEntry = FuelEntry(
        id: widget.editingFuel?.id,
        vehicleId: _selectedFuelVehicleId,
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
        await FuelRepository.updateFuelEntry(fuelEntry);
      } else {
        await FuelRepository.createFuelEntry(fuelEntry);
      }

      if (mounted) {
        AppDialogs.showSuccess(
          context,
          _isEditMode
              ? 'Fuel entry updated successfully!'
              : 'Fuel entry saved successfully!',
        );

        // Invalidate dashboard cache so it reloads from repository
        DataPrefetchService.instance.invalidateCache();

        // Navigate to dashboard after saving
        // Use a small delay to ensure dialog is shown before navigation
        if (mounted) {
          context.pop(true);
        }
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    String? label,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      labelText: label,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.tokens.textSecondary,
        fontSize: 14,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.tokens.textTertiary,
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: primaryColor, size: 20),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: primaryColor, size: 20),
              onPressed: onSuffixTap,
            )
          : null,
      isDense: true,
      // Rest handled by inputDecorationTheme in AppTheme
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: context.tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currencySymbol${grandTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${quantity.toStringAsFixed(1)} $_fuelUnit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: context.tokens.textSecondary,
                ),
              ),
              Text(
                '@ $currencySymbol${price.toStringAsFixed(3)}/$_fuelUnit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: context.tokens.textSecondary,
                ),
              ),
              if (!_isReeferFuel &&
                  (_defQuantityController.text.isNotEmpty &&
                      (double.tryParse(_defQuantityController.text) ?? 0) >
                          0)) ...[
                const SizedBox(height: 4),
                Text(
                  '+ DEF: ${double.parse(_defQuantityController.text).toStringAsFixed(1)} $_fuelUnit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: context.tokens.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (!_defFromYard)
                  Text(
                    '@ $currencySymbol${(double.tryParse(_defPriceController.text) ?? 0).toStringAsFixed(3)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: context.tokens.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    '(Yard)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.success,
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
                    label: i == 0 ? 'Trailer Number' : 'Trailer ${i + 1}',
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
                        color: Theme.of(context).colorScheme.error,
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
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: Theme.of(context).colorScheme.tertiary,
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

class CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData prefixIcon;
  final Future<Iterable<String>> Function(String) optionsBuilder;
  final String? label;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextCapitalization textCapitalization;
  final void Function(String)? onSelected;
  final InputDecoration? decoration;

  const CustomAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    required this.optionsBuilder,
    this.label,
    this.suffixIcon,
    this.onSuffixTap,
    this.textCapitalization = TextCapitalization.sentences,
    this.onSelected,
    this.decoration,
    super.key,
  });

  @override
  State<CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<CustomAutocompleteField> {
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: widget.focusNode,
          onSelected: widget.onSelected,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.optionsBuilder(textEditingValue.text);
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return CompositedTransformTarget(
                  link: _layerLink,
                  child: TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    textCapitalization: widget.textCapitalization,
                    decoration:
                        widget.decoration ??
                        InputDecoration(
                          labelText: widget.label,
                          hintText: widget.hint,
                          prefixIcon: Icon(
                            widget.prefixIcon,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          suffixIcon: widget.suffixIcon != null
                              ? IconButton(
                                  icon: Icon(
                                    widget.suffixIcon,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: widget.onSuffixTap,
                                )
                              : null,
                        ),
                    onSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                  ),
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
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: const Offset(
                      0.0,
                      56.0,
                    ), // Approximate height of TextField
                    child: Material(
                      elevation: 8.0,
                      color: context.tokens.surfaceContainer,
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: context.tokens.textPrimary,
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }
}
