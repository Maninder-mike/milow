import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/custom_autocomplete_field.dart';

import 'package:milow/features/inspections/presentation/widgets/inspection_signature_pad.dart';
import 'package:milow/features/inspections/presentation/providers/inspection_provider.dart';
import 'package:milow_core/milow_core.dart';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class InspectionFormPage extends StatefulWidget {
  final String? inspectionId;

  const InspectionFormPage({super.key, this.inspectionId});

  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends State<InspectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool get isEditing => widget.inspectionId != null;

  // Form Fields
  String _driverId = '';
  String _type = 'pre-trip'; // pre-trip, post-trip

  // Signature
  Uint8List? _signatureBytes;
  String? _existingSignatureUrl;

  // Odometer Unit
  String _odometerUnit = 'mi'; // 'mi' or 'km'

  // Defects
  // Map of Category -> List of selected defect names
  final Map<String, List<String>> _selectedDefects = {};

  // Photo Evidence Types
  // Map of "Category-Item" -> Defect ID (UUID)
  final Map<String, String> _defectIds = {};
  // Map of Defect ID -> List of local image files
  final Map<String, List<File>> _defectPhotos = {};

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final FocusNode _vehicleFocusNode = FocusNode();

  final List<String> _vehicles = ['Truck 101', 'Truck 102', 'Trailer 505'];

  // Defect Categories
  final Map<String, List<String>> _defectCategories = {
    'Brakes': [
      'Service Brakes',
      'Parking Brake',
      'Brake Connections',
      'Brake Lines',
    ],
    'Lights': [
      'Headlights',
      'Tail/Stop Lights',
      'Turn Signals',
      'Clearance/Marker',
    ],
    'Tires': ['Tires', 'Wheels/Rims', 'Lug Nuts', 'Mud Flaps'],
    'Engine': ['Fluid Leaks', 'Oil Level', 'Coolant Level', 'Belts/Hoses'],
    'Safety': [
      'Fire Extinguisher',
      'Triangles/Flares',
      'Horn',
      'Mirrors',
      'Wipers',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadPreferences();
    // Get current driver ID from Supabase auth
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _driverId = user.id;
    } else {
      // Fallback or handle unauthenticated state (though AuthGuard should prevent this)
      _driverId = '';
    }

    if (widget.inspectionId != null) {
      setState(() => _isLoading = true);
      try {
        if (!mounted) return;
        // Fetch inspection from provider
        final provider = Provider.of<InspectionProvider>(
          context,
          listen: false,
        );
        final inspection = provider.inspections.firstWhere(
          (i) => i.id == widget.inspectionId,
        );
        setState(() {
          _populateForm(inspection);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading inspection: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    _vehicleFocusNode.dispose();
    super.dispose();
  }

  String _getDefectKey(String category, String defect) => '$category-$defect';

  String _getOrCreateDefectId(String category, String defect) {
    final key = _getDefectKey(category, defect);
    if (!_defectIds.containsKey(key)) {
      _defectIds[key] = const Uuid().v4();
    }
    return _defectIds[key]!;
  }

  void _populateForm(Inspection inspection) {
    debugPrint('Populating form with inspection type: ${inspection.type}');
    _driverId = inspection.driverId;
    _type = inspection.type;
    _vehicleController.text = inspection.vehicleId;
    _odometerController.text = inspection.odometer.toString();
    _notesController.text = inspection.notes ?? '';
    _existingSignatureUrl = inspection.signatureUrl;

    // Populate Defects
    for (var defect in inspection.defects) {
      if (!_selectedDefects.containsKey(defect.category)) {
        _selectedDefects[defect.category] = [];
      }
      _selectedDefects[defect.category]!.add(defect.item);
      // Map existing defect ID
      _defectIds[_getDefectKey(defect.category, defect.item)] = defect.id;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (widget.inspectionId == null) {
        // Only pre-fill for new inspections
        final lastVehicle = prefs.getString('last_vehicle_id');
        if (lastVehicle != null && lastVehicle.isNotEmpty) {
          _vehicleController.text = lastVehicle;
        }
        _odometerUnit = prefs.getString('last_odometer_unit') ?? 'mi';
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_vehicle_id', _vehicleController.text);
    await prefs.setString('last_odometer_unit', _odometerUnit);
  }

  void _toggleDefect(String category, String defect) {
    setState(() {
      if (!_selectedDefects.containsKey(category)) {
        _selectedDefects[category] = [];
      }

      if (_selectedDefects[category]!.contains(defect)) {
        _selectedDefects[category]!.remove(defect);
        if (_selectedDefects[category]!.isEmpty) {
          _selectedDefects.remove(category);
        }
      } else {
        _selectedDefects[category]!.add(defect);
        // Ensure ID is created when selected
        _getOrCreateDefectId(category, defect);
      }
    });
  }

  Future<void> _takePhoto(String category, String defect) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, // Optimize size
      );

      if (photo == null) return;

      final defectId = _getOrCreateDefectId(category, defect);
      final file = File(photo.path);

      setState(() {
        if (!_defectPhotos.containsKey(defectId)) {
          _defectPhotos[defectId] = [];
        }
        _defectPhotos[defectId]!.add(file);

        // Auto-select defect if adding photo
        if (!_selectedDefects.containsKey(category)) {
          _selectedDefects[category] = [];
        }
        if (!_selectedDefects[category]!.contains(defect)) {
          _selectedDefects[category]!.add(defect);
        }
      });

      // Save to repository immediately
      if (mounted) {
        await Provider.of<InspectionProvider>(
          context,
          listen: false,
        ).savePhoto(file, defectId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
      }
    }
  }

  void _removePhoto(String defectId, File photo) {
    setState(() {
      _defectPhotos[defectId]?.remove(photo);
    });
    // Optional: Delete from repo/disk if needed, but for now just UI removal
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _saveInspection() async {
    if (!_formKey.currentState!.validate()) return;

    await _savePreferences();

    // If editing and no new signature, we assume keeping the old one (logic in repository needs to handle this)
    if (!isEditing && _signatureBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign the inspection')),
        );
      }
      return;
    }
    // If editing, existing sig must exist or new sig must be provided
    if (isEditing && _existingSignatureUrl == null && _signatureBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign the inspection')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final inspectionId = widget.inspectionId ?? const Uuid().v4();

      // Convert selected defects map to List<InspectionDefect>
      final List<InspectionDefect> defectsList = [];
      _selectedDefects.forEach((category, defects) {
        for (final defectName in defects) {
          final defectId = _getOrCreateDefectId(category, defectName);
          defectsList.add(
            InspectionDefect(
              id: defectId,
              inspectionId: inspectionId,
              category: category,
              item: defectName,
              comment: null,
              isRepaired: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      });

      // Fetch current location
      String locationStr = 'Unknown Location';
      try {
        // We use a separate try-catch so location failure doesn't block saving
        final position = await _determinePosition();
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            locationStr =
                '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                    .trim();
            if (locationStr == ',') locationStr = position.toString();
          } else {
            locationStr = '${position.latitude}, ${position.longitude}';
          }
        } catch (_) {
          // Fallback to coordinates if geocoding fails
          locationStr = '${position.latitude}, ${position.longitude}';
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
        // Continue with 'Unknown Location'
      }

      final inspection = Inspection(
        id: inspectionId,
        driverId: _driverId,
        vehicleId: _vehicleController.text,
        type: _type,
        odometer: double.tryParse(_odometerController.text) ?? 0,
        location: locationStr,
        signedAt: DateTime.now(),
        updatedAt: DateTime.now(), // Always update timestamp
        notes: _notesController.text,
        defects: defectsList,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;

      await Provider.of<InspectionProvider>(
        context,
        listen: false,
      ).saveInspection(inspection, signatureBytes: _signatureBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving inspection: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        title: Text(
          widget.inspectionId == null ? 'New Inspection' : 'Edit Inspection',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: tokens.surfaceContainer,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveInspection,
            child: Text(
              'SAVE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: tokens.spacingS),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacingM),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(tokens, colorScheme),
                    SizedBox(height: tokens.spacingL),
                    _buildGeneralSection(tokens, colorScheme),
                    SizedBox(height: tokens.spacingL),
                    _buildDefectsSection(tokens, colorScheme),
                    SizedBox(height: tokens.spacingL),
                    _buildNotesSection(tokens, colorScheme),
                    SizedBox(height: tokens.spacingL),
                    _buildSignatureSection(tokens, colorScheme),
                    SizedBox(height: tokens.spacingXL),
                    // Save button moved to AppBar
                    /*
                    FilledButton(
                      onPressed: _saveInspection,
                      child: Text('SUBMIT INSPECTION'),
                    ),
                    */
                    SizedBox(height: tokens.spacingXL),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(DesignTokens tokens, ColorScheme colorScheme) {
    final passed = _selectedDefects.isEmpty;
    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: passed ? tokens.successContainer : tokens.errorContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        border: Border.all(
          color: passed ? tokens.success : tokens.error,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.warning_amber_rounded,
            color: passed ? tokens.success : tokens.error,
            size: 32,
          ),
          SizedBox(width: tokens.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed ? 'Vehicle Safe to Operate' : 'Defects Reported',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: passed ? tokens.success : tokens.error,
                  ),
                ),
                Text(
                  passed
                      ? 'No defects marked.'
                      : '${_selectedDefects.length} categories with issues.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    required DesignTokens tokens,
  }) {
    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        border: Border.all(color: tokens.subtleBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.sectionLabelColor,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: tokens.spacingM),
          child,
        ],
      ),
    );
  }

  Widget _buildGeneralSection(DesignTokens tokens, ColorScheme colorScheme) {
    return _buildSectionCard(
      title: 'Inspection Details',
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inspection Type Segmented Control
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: tokens.inputBackground,
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                  border: Border.all(color: tokens.inputBorder),
                ),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'pre-trip',
                      label: Text('Pre-Trip'),
                      icon: Icon(Icons.start),
                    ),
                    ButtonSegment(
                      value: 'post-trip',
                      label: Text('Post-Trip'),
                      icon: Icon(Icons.flag),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      setState(() {
                        _type = newSelection.first;
                      });
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.primaryContainer;
                      }
                      return null;
                    }),
                    visualDensity: VisualDensity.comfortable,
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeS),
                      ),
                    ),
                    side: WidgetStateProperty.all(BorderSide.none),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: tokens.spacingM),

          // Vehicle & Location
          CustomAutocompleteField(
            label: 'Vehicle ID',
            hint: 'Select or enter vehicle',
            controller: _vehicleController,
            focusNode: _vehicleFocusNode,
            options: _vehicles,
            prefixIcon: Icons.local_shipping_outlined,
            validator: (value) =>
                value == null || value.isEmpty ? 'Required' : null,
          ),
          SizedBox(height: tokens.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Odometer',
                    hintText: 'Ex: 120500',
                    prefixIcon: Icon(Icons.speed, color: colorScheme.primary),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  height: 56, // Match standard input height
                  decoration: BoxDecoration(
                    color: tokens.inputBackground,
                    borderRadius: BorderRadius.circular(tokens.shapeS),
                    border: Border.all(color: tokens.inputBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildUnitToggle(tokens, colorScheme, 'mi'),
                      Container(
                        width: 1,
                        height: 24,
                        color: tokens.inputBorder,
                      ),
                      _buildUnitToggle(tokens, colorScheme, 'km'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefectsSection(DesignTokens tokens, ColorScheme colorScheme) {
    return _buildSectionCard(
      title: 'Vehicle Defects',
      tokens: tokens,
      child: Column(
        children: [
          ..._defectCategories.entries.map((entry) {
            final category = entry.key;
            final defects = entry.value;
            final hasDefects = _selectedDefects.containsKey(category);

            return Card(
              margin: EdgeInsets.only(bottom: tokens.spacingS),
              elevation: 0,
              color: hasDefects
                  ? tokens.errorContainer.withValues(alpha: 0.3)
                  : tokens.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.shapeM),
                side: BorderSide(
                  color: hasDefects ? tokens.error : tokens.subtleBorderColor,
                ),
              ),
              child: ExpansionTile(
                title: Text(
                  category,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: hasDefects ? tokens.error : colorScheme.onSurface,
                  ),
                ),
                leading: Icon(
                  hasDefects ? Icons.warning_amber : Icons.check_circle_outline,
                  color: hasDefects ? tokens.error : tokens.success,
                ),
                childrenPadding: EdgeInsets.all(tokens.spacingM),
                children: [
                  ...defects.map((defect) {
                    final isSelected =
                        _selectedDefects[category]?.contains(defect) ?? false;
                    final defectId = _getOrCreateDefectId(category, defect);
                    final photos = _defectPhotos[defectId] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilterChip(
                                label: Text(defect),
                                selected: isSelected,
                                onSelected: (_) =>
                                    _toggleDefect(category, defect),
                                selectedColor: tokens.errorContainer,
                                checkmarkColor: tokens.error,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? tokens.error
                                      : colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: () => _takePhoto(category, defect),
                                tooltip: 'Add Photo',
                              ),
                          ],
                        ),
                        if (isSelected && photos.isNotEmpty)
                          Container(
                            height: 80,
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final photo = photos[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        photo,
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _removePhoto(defectId, photo),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesSection(DesignTokens tokens, ColorScheme colorScheme) {
    return _buildSectionCard(
      title: 'Remarks',
      tokens: tokens,
      child: TextFormField(
        controller: _notesController,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Add any additional notes here...',
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  // No longer needed
  // final GlobalKey<SignaturePadState> _signatureKey = GlobalKey();

  Widget _buildSignatureSection(DesignTokens tokens, ColorScheme colorScheme) {
    return _buildSectionCard(
      title: 'Driver Signature',
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_signatureBytes != null)
            Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Image.memory(_signatureBytes!, fit: BoxFit.contain),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _signatureBytes = null;
                      // Only clear controller if we just signed
                      // But effectively we reset to "no signature" state
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear New Signature'),
                ),
              ],
            )
          else if (_existingSignatureUrl != null)
            Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Image.network(
                    _existingSignatureUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Text('Error loading signature')),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Signed previously',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _existingSignatureUrl = null;
                      // Now user must sign
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Update Signature'),
                ),
              ],
            )
          else
            Column(
              children: [
                InspectionSignaturePad(
                  onSigned: (bytes) {
                    setState(() {
                      _signatureBytes = bytes;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text('Sign above'),
                    Spacer(),
                    // Clear handled within SignaturePad or by re-signing
                  ],
                ),
              ],
            ),
          SizedBox(height: tokens.spacingS),
          Text(
            'I certify that this report is true and correct.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: tokens.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(
    DesignTokens tokens,
    ColorScheme colorScheme,
    String unit,
  ) {
    final isSelected = _odometerUnit == unit;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _odometerUnit = unit),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        child: Container(
          alignment: Alignment.center,
          color: isSelected ? colorScheme.primaryContainer : null,
          child: Text(
            unit.toUpperCase(),
            style: GoogleFonts.outfit(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
