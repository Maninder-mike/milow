import 'package:flutter/material.dart';

import 'package:milow/core/constants/design_tokens.dart';
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

  // Scroll-to-hide header disabled per user request
  final ScrollController _tripScrollController = ScrollController();
  final ScrollController _fuelScrollController = ScrollController();

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
      initialIndex: widget.editingFuel != null ? 1 : widget.initialTab,
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

    // _tripScrollController.addListener(_onTripScroll);
    // _fuelScrollController.addListener(_onFuelScroll);
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

  @override
  void dispose() {
    _headerAnimationController.dispose();
    // _tripScrollController.removeListener(_onTripScroll);
    // _fuelScrollController.removeListener(_onFuelScroll);
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
    final tokens = context.tokens;
    final bgColor = tokens.surfaceContainer;
    final borderColor = tokens.inputBorder;
    final textColor = tokens.textPrimary;
    final hintColor = tokens.textTertiary;

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
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: hintColor,
                  ),
                  hint: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: hintColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Select or add border',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: hintColor),
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
                            Icon(
                              Icons.flag_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                border,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: textColor),
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
              icon: Icon(
                Icons.add_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
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
                icon: Icon(
                  Icons.clear_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
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
    String? label,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
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
                    label: label,
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
                );
              },
        );
      },
    );
  }

  // [NEW] Quick Actions Section (Capsules)
  Widget _buildQuickActions() {
    // Only show for existing trips
    if (widget.editingTrip == null) return const SizedBox.shrink();

    final hasPickups =
        _pickupControllers.isNotEmpty &&
        _pickupControllers.any((c) => c.text.isNotEmpty);

    final actions = <Widget>[];

    if (hasPickups) {
      // Pickup Mode Actions
      actions.add(
        _buildActionChip(
          label: 'Picked up load',
          icon: Icons.check_circle_outlined,
          color: Theme.of(context).colorScheme.primary,
          onTap: () {
            // Remove first pickup location
            if (_pickupControllers.isNotEmpty) {
              final removedLocation = _pickupControllers[0].text;
              _removePickupLocation(0);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Marked picked up at $removedLocation. Save to persist.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      );
      actions.add(
        _buildActionChip(
          label: 'Add pickup time',
          icon: Icons.access_time_rounded,
          color: Theme.of(context).colorScheme.tertiary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select "Date & Time" field below')),
            );
            // Optionally scroll to date field
          },
        ),
      );
      actions.add(
        _buildActionChip(
          label: 'Add documents BOL',
          icon: Icons.upload_file_rounded,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document upload coming soon')),
            );
          },
        ),
      );
    } else {
      // Delivery Mode Actions
      actions.add(
        _buildActionChip(
          label: 'Arrived at delivery',
          icon: Icons.location_on_outlined,
          color: context.tokens.info,
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Marked as arrived')));
          },
        ),
      );
      actions.add(
        _buildActionChip(
          label: 'Deliver load',
          icon: Icons.check_circle_rounded,
          color: context.tokens.success,
          onTap: () {
            // Logic to complete trip or remove delivery
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delivery logic pending')),
            );
          },
        ),
      );
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

  // Build generic action chip
  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: context.tokens.textPrimary),
      ),
      backgroundColor: context.tokens.surfaceContainer,
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
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
                child: _buildAutocompleteField(
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
                                    'Add Entry',
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
                                onPressed: () {
                                  if (_tabController.index == 0) {
                                    _validateAndSaveTrip();
                                  } else {
                                    _validateAndSaveFuel();
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'Save',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
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
                      decoration: _inputDecoration(
                        label: 'Trip Number',
                        hint: 'e.g., TR-12345',
                        prefixIcon: Icons.tag,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAutocompleteField(
                      controller: _tripTruckNumberController,
                      focusNode: _tripTruckFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      hint: 'e.g., T-101',
                      prefixIcon: Icons.local_shipping,
                      label: 'Truck Number',
                      optionsBuilder:
                          PredictionService.instance.getTruckSuggestions,
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
                        onTap: () => setState(() => _isReeferFuel = false),
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
                        onTap: () => setState(() => _isReeferFuel = true),
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
              _buildAutocompleteField(
                controller: _truckNumberController,
                focusNode: _truckFocusNode,
                textCapitalization: TextCapitalization.characters,
                label: _isReeferFuel ? 'Reefer Number' : 'Truck Number',
                hint: _isReeferFuel ? 'e.g., R-101' : 'e.g., T-101',
                prefixIcon: _isReeferFuel
                    ? Icons.ac_unit
                    : Icons.local_shipping,
                optionsBuilder: PredictionService.instance.getTruckSuggestions,
              ),
              const SizedBox(height: 12),
              _buildAutocompleteField(
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
    final outlineVariant = Theme.of(context).colorScheme.outlineVariant;

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
      filled: true,
      fillColor: context.tokens.inputBackground,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
