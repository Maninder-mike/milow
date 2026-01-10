import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terminal/core/constants/location_data.dart';
import 'package:terminal/core/widgets/form_widgets.dart';
import '../shared/trip_entry_scaffold.dart';

class PickUpPage extends StatefulWidget {
  final bool isDialog;
  final Map<String, dynamic>? pickupData;
  const PickUpPage({super.key, this.isDialog = false, this.pickupData});

  @override
  State<PickUpPage> createState() => _PickUpPageState();
}

class _PickUpPageState extends State<PickUpPage> {
  // Core Location & Company
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String _state = 'Ontario'; // Default
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Contact
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _faxController = TextEditingController();

  // Schedule & Reference
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    8,
    0,
  );
  final _refNumberController = TextEditingController(); // PO / PU numbers
  String _status = 'Scheduled'; // New status field
  String _sortColumn = 'pickup_date';
  bool _isAscending = false;

  // Schedule & Logistics state
  String _appointmentType = 'Live Load';
  String _schedulingWindow = 'Strict Appointment';

  bool _driverAssist = false;
  bool _ppeRequired = false;
  bool _overnightParking = false;
  bool _strictLatePolicy = false;
  bool _callBeforeArrival = false;

  // New Logistic Options
  bool _blindShipment = false;
  bool _scaleOnSite = false;
  bool _cleanTrailer = false;
  bool _hazmat = false;
  bool _facility247 = false;
  bool _strapsRequired = false;

  // Cargo Details
  final _goodsController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController();
  String _weightUnit = 'Lbs';

  // Notes
  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _pickups = [];
  List<Map<String, dynamic>> _filteredPickups = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.pickupData != null) {
      _populateFields(widget.pickupData!);
    }
    if (!widget.isDialog) {
      _fetchPickups();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _faxController.dispose();
    _refNumberController.dispose();
    _goodsController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    _companyNameController.text = data['shipper_name'] ?? '';
    _addressController.text = data['address'] ?? '';
    _cityController.text = data['city'] ?? '';
    _state = data['state_province'] ?? 'Ontario';
    _zipCodeController.text = data['postal_code'] ?? '';
    _countryController.text = data['country'] ?? 'Canada';
    _contactController.text = data['contact_person'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _emailController.text = data['email'] ?? '';
    _faxController.text = data['fax'] ?? '';
    if (data['pickup_date'] != null) {
      _selectedDate = DateTime.parse(data['pickup_date']);
    }
    if (data['start_time'] != null) {
      final parts = data['start_time'].split(':');
      _startTime = DateTime(
        2000,
        1,
        1,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    _refNumberController.text = data['reference_number'] ?? '';
    _appointmentType = data['appointment_type'] ?? 'Live Load';
    _schedulingWindow = data['scheduling_window'] ?? 'Strict Appointment';
    _ppeRequired = data['is_ppe_required'] ?? false;
    _driverAssist = data['is_driver_assist'] ?? false;
    _overnightParking = data['is_overnight_parking'] ?? false;
    _strictLatePolicy = data['is_strict_late_policy'] ?? false;
    _callBeforeArrival = data['is_call_before_arrival'] ?? false;
    _blindShipment = data['is_blind_shipment'] ?? false;
    _scaleOnSite = data['is_scale_on_site'] ?? false;
    _cleanTrailer = data['is_clean_trailer'] ?? false;
    _hazmat = data['is_hazmat'] ?? false;
    _facility247 = data['is_facility_247'] ?? false;
    _strapsRequired = data['is_straps_required'] ?? false;
    _goodsController.text = data['commodity'] ?? '';
    _weightController.text = (data['weight'] ?? '').toString();
    _weightUnit = data['weight_unit'] ?? 'Lbs';
    _quantityController.text = data['quantity'] ?? '';
    _notesController.text = data['driver_instructions'] ?? '';
    _internalNotesController.text = data['internal_notes'] ?? '';
    _status = data['status'] ?? 'Scheduled';
  }

  Future<void> _fetchPickups() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('pickups')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pickups = List<Map<String, dynamic>>.from(response);
          _filteredPickups = _pickups;
          _sortPickups(); // Apply current sorting
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pickups: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPickups = _pickups.where((item) {
        final name = (item['shipper_name'] ?? '').toLowerCase();
        final city = (item['city'] ?? '').toLowerCase();
        final ref = (item['reference_number'] ?? '').toLowerCase();
        return name.contains(query) ||
            city.contains(query) ||
            ref.contains(query);
      }).toList();
      _sortPickups(); // Re-sort after filtering
    });
  }

  void _sortPickups() {
    _filteredPickups.sort((a, b) {
      dynamic aVal = a[_sortColumn];
      dynamic bVal = b[_sortColumn];

      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;

      int comparison;
      if (aVal is num && bVal is num) {
        comparison = aVal.compareTo(bVal);
      } else {
        comparison = aVal.toString().toLowerCase().compareTo(
          bVal.toString().toLowerCase(),
        );
      }

      return _isAscending ? comparison : -comparison;
    });
  }

  void _onHeaderTap(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _sortPickups();
    });
  }

  void _editPickup(Map<String, dynamic> pickup) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PickUpPage(isDialog: true, pickupData: pickup),
    ).then((_) => _fetchPickups());
  }

  Future<void> _deletePickup(Map<String, dynamic> pickup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete "${pickup['shipper_name']}"?',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('pickups')
            .delete()
            .eq('id', pickup['id']);

        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Record deleted successfully'),
              severity: InfoBarSeverity.success,
              onClose: close,
            ),
          );
          _fetchPickups();
        }
      } catch (e) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: Text('Error deleting record: $e'),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        }
      }
    }
  }

  Future<void> _savePickup() async {
    if (_companyNameController.text.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Shipper name is required'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'shipper_name': _companyNameController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state_province': _state,
        'postal_code': _zipCodeController.text,
        'country': _countryController.text,
        'contact_person': _contactController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'fax': _faxController.text,
        'pickup_date': _selectedDate.toIso8601String().split('T')[0],
        'start_time':
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        'appointment_type': _appointmentType,
        'scheduling_window': _schedulingWindow,
        'reference_number': _refNumberController.text,
        'is_ppe_required': _ppeRequired,
        'is_driver_assist': _driverAssist,
        'is_overnight_parking': _overnightParking,
        'is_strict_late_policy': _strictLatePolicy,
        'is_call_before_arrival': _callBeforeArrival,
        'is_blind_shipment': _blindShipment,
        'is_scale_on_site': _scaleOnSite,
        'is_clean_trailer': _cleanTrailer,
        'is_hazmat': _hazmat,
        'is_facility_247': _facility247,
        'is_straps_required': _strapsRequired,
        'commodity': _goodsController.text,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'weight_unit': _weightUnit,
        'quantity': _quantityController.text,
        'driver_instructions': _notesController.text,
        'internal_notes': _internalNotesController.text,
        'status': _status,
      };

      if (widget.pickupData != null) {
        await Supabase.instance.client
            .from('pickups')
            .update(data)
            .eq('id', widget.pickupData!['id']);
      } else {
        await Supabase.instance.client.from('pickups').insert(data);
      }

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Pickup saved successfully!'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving pickup: $e');
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text('Error saving record: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    if (widget.isDialog) {
      return Transform.translate(
        offset: _offset,
        child: ContentDialog(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
          title: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() => _offset += details.delta);
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.pickupData == null
                          ? 'Add New Pickup'
                          : 'Edit Pickup',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _savePickup,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(),
                      )
                    : const Text('Save Pickup'),
              ),
            ],
          ),
          content: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Location
                      const FluentSectionHeader(title: 'Pickup Location'),
                      const SizedBox(height: 16),

                      // Search Row
                      FluentLabeledInput(
                        label: 'Company / Shipper Name',
                        controller: _companyNameController,
                      ),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Street Address',
                        controller: _addressController,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: FluentLabeledInput(
                              label: 'City',
                              controller: _cityController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    'State/Prov',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ComboBox<String>(
                                  value: _state,
                                  placeholder: const Text(
                                    'Select...',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  items: [
                                    // Canada
                                    ...LocationData.canadianProvinces.entries
                                        .map(
                                          (e) => ComboBoxItem(
                                            value: e.value,
                                            child: Text(
                                              '${e.key} - ${e.value}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                    // USA
                                    ...LocationData.usStates.entries.map(
                                      (e) => ComboBoxItem(
                                        value: e.value,
                                        child: Text(
                                          '${e.key} - ${e.value}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _state = v ?? 'Ontario'),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Zip Code',
                              controller: _zipCodeController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
                                  child: Text(
                                    'Country',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ComboBox<String>(
                                  value: _countryController.text.isEmpty
                                      ? 'Canada'
                                      : _countryController.text,
                                  items: LocationData.countries
                                      .map(
                                        (e) => ComboBoxItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () =>
                                        _countryController.text = v ?? 'Canada',
                                  ),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const FluentSectionHeader(
                        title: 'Contact Details',
                        showDivider: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Contact Person',
                              controller: _contactController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Phone',
                              controller: _phoneController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Email',
                              controller: _emailController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Fax',
                              controller: _faxController,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const FluentSectionHeader(
                        title: 'Schedule & Reference',
                        showDivider: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pickup Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DatePicker(
                                  selected: _selectedDate,
                                  onChanged: (v) =>
                                      setState(() => _selectedDate = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TimePicker(
                                  selected: _startTime,
                                  onChanged: (v) =>
                                      setState(() => _startTime = v),
                                  hourFormat: HourFormat.HH,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row: Appointment Type & Scheduling Window
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
                                  child: Text(
                                    'Appointment Type',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ComboBox<String>(
                                  value: _appointmentType,
                                  items: ['Live Load', 'Pickup Trailer']
                                      .map(
                                        (e) => ComboBoxItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _appointmentType = v ?? 'Live Load',
                                  ),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
                                  child: Text(
                                    'Scheduling Window',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ComboBox<String>(
                                  value: _schedulingWindow,
                                  items:
                                      [
                                            'Strict Appointment',
                                            'FCFS',
                                            'Window (2hr)',
                                          ]
                                          .map(
                                            (e) => ComboBoxItem(
                                              value: e,
                                              child: Text(
                                                e,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setState(
                                    () => _schedulingWindow =
                                        v ?? 'Strict Appointment',
                                  ),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FluentOptionChip(
                            label: 'PPE Required',
                            icon: FluentIcons.shield,
                            value: _ppeRequired,
                            onChanged: (v) => setState(() => _ppeRequired = v),
                          ),
                          FluentOptionChip(
                            label: 'Driver Assist',
                            icon: FluentIcons.people,
                            value: _driverAssist,
                            onChanged: (v) => setState(() => _driverAssist = v),
                          ),
                          FluentOptionChip(
                            label: 'Overnight Parking',
                            icon: FluentIcons.parking_location,
                            value: _overnightParking,
                            onChanged: (v) =>
                                setState(() => _overnightParking = v),
                          ),
                          FluentOptionChip(
                            label: 'Strict "Late" Policy',
                            icon: FluentIcons.timer,
                            value: _strictLatePolicy,
                            onChanged: (v) =>
                                setState(() => _strictLatePolicy = v),
                          ),
                          FluentOptionChip(
                            label: 'Call 1hr Before',
                            icon: FluentIcons.phone,
                            value: _callBeforeArrival,
                            onChanged: (v) =>
                                setState(() => _callBeforeArrival = v),
                          ),
                          FluentOptionChip(
                            label: 'Blind Shipment',
                            icon: FluentIcons.lock,
                            value: _blindShipment,
                            onChanged: (v) =>
                                setState(() => _blindShipment = v),
                          ),
                          FluentOptionChip(
                            label: 'Scale on Site',
                            icon: FluentIcons.speed_high,
                            value: _scaleOnSite,
                            onChanged: (v) => setState(() => _scaleOnSite = v),
                          ),
                          FluentOptionChip(
                            label: 'Clean / Food Grade',
                            icon: FluentIcons.health,
                            value: _cleanTrailer,
                            onChanged: (v) => setState(() => _cleanTrailer = v),
                          ),
                          FluentOptionChip(
                            label: 'Hazmat',
                            icon: FluentIcons.warning,
                            value: _hazmat,
                            onChanged: (v) => setState(() => _hazmat = v),
                          ),
                          FluentOptionChip(
                            label: '24/7 Facility',
                            icon: FluentIcons.clock,
                            value: _facility247,
                            onChanged: (v) => setState(() => _facility247 = v),
                          ),
                          FluentOptionChip(
                            label: 'Straps / Load Bars',
                            icon: FluentIcons.link,
                            value: _strapsRequired,
                            onChanged: (v) =>
                                setState(() => _strapsRequired = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: FluentLabeledInput(
                              label: 'Reference Numbers',
                              controller: _refNumberController,
                              placeholder: 'PO #, Pickup #, DO #',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ComboBox<String>(
                                  value: _status,
                                  items: ['Scheduled', 'Picked Up', 'Cancelled']
                                      .map((e) {
                                        return ComboBoxItem(
                                          value: e,
                                          child: Text(e),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _status = v ?? 'Scheduled',
                                  ),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const FluentSectionHeader(
                        title: 'Cargo Information',
                        showDivider: true,
                      ),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Commodity / Goods',
                        controller: _goodsController,
                        placeholder: 'e.g. Auto Parts, Produce',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
                                  child: Text(
                                    'Weight',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormBox(
                                        controller: _weightController,
                                        placeholder: '0.00',
                                        padding: const EdgeInsets.all(10),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildWeightUnitToggle(isLight),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FluentLabeledInput(
                              label: 'Quantity',
                              controller: _quantityController,
                              placeholder: 'Pallets / Pieces',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const FluentSectionHeader(
                        title: 'Instructions & Notes',
                        showDivider: true,
                      ),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Driver Instructions',
                        controller: _notesController,
                        maxLines: 3,
                        placeholder: 'Specific instructions for the driver...',
                      ),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Internal / Office Notes',
                        controller: _internalNotesController,
                        maxLines: 2,
                        placeholder: 'Private notes for dispatch...',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // MAIN LIST PAGE VIEW
    return TripEntryScaffold(
      title: 'Pick Up Information',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsRow(theme, isLight),
            const SizedBox(height: 32),
            _buildSearchHeader(theme, isLight),
            const SizedBox(height: 16),
            _buildShippersSection(context, isLight),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(FluentThemeData theme, bool isLight) {
    int total = _pickups.length;
    int today = _pickups.where((p) {
      final date = p['pickup_date'];
      if (date == null) return false;
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      return date == todayStr;
    }).length;
    int completed = _pickups.where((p) => p['status'] == 'Picked Up').length;

    return Row(
      children: [
        _buildStatCard(
          'Total Pickups',
          total.toString(),
          FluentIcons.package,
          theme.accentColor,
          theme,
          isLight,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Today',
          today.toString(),
          FluentIcons.calendar,
          Colors.orange,
          theme,
          isLight,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Completed',
          completed.toString(),
          FluentIcons.completed,
          Colors.green,
          theme,
          isLight,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    FluentThemeData theme,
    bool isLight,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(FluentThemeData theme, bool isLight) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: _searchController,
            placeholder: 'Search by shipper, city or reference...',
            prefix: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(FluentIcons.search, size: 14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: () => _openAddPickupDialog(context),
          child: const Row(
            children: [
              Icon(FluentIcons.add, size: 12),
              SizedBox(width: 8),
              Text('Add Pickup'),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddPickupDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PickUpPage(isDialog: true),
    ).then((_) => _fetchPickups());
  }

  Widget _buildWeightUnitButton(String unit, bool isLight) {
    final theme = FluentTheme.of(context);
    final isSelected = _weightUnit == unit;
    return GestureDetector(
      onTap: () => setState(() => _weightUnit = unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : theme.resources.textFillColorSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWeightUnitToggle(bool isLight) {
    final theme = FluentTheme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWeightUnitButton('Lbs', isLight),
          const SizedBox(width: 2),
          _buildWeightUnitButton('Kg', isLight),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, String column, {int flex = 1}) {
    final theme = FluentTheme.of(context);
    final isSorted = _sortColumn == column;

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _onHeaderTap(column),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isSorted) ...[
              const SizedBox(width: 4),
              Icon(
                _isAscending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down,
                size: 8,
                color: theme.accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShippersSection(BuildContext context, bool isLight) {
    final theme = FluentTheme.of(context);
    // Reusing the table visualization
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 40,
                  child: Text(
                    'Seq',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildSortableHeader('Status', 'status', flex: 2),
                _buildSortableHeader('Shipper', 'shipper_name', flex: 3),
                _buildSortableHeader('Ref #', 'reference_number', flex: 2),
                _buildSortableHeader('Date', 'pickup_date', flex: 2),
                _buildSortableHeader('Address', 'city', flex: 4),
                _buildSortableHeader('Cargo', 'commodity', flex: 2),
                const SizedBox(width: 48), // Actions spacer
              ],
            ),
          ),
          // Rows
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: ProgressRing(),
              ),
            )
          else
            ..._filteredPickups.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.resources.dividerStrokeColorDefault,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text((index + 1).toString())),

                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildStatusBadge(item['status'] ?? 'Scheduled'),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['shipper_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['reference_number'] ?? '--',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['pickup_date'] ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            item['start_time']?.toString().substring(0, 5) ??
                                '',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        item['address'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${item['weight'] ?? '--'} ${item['weight_unit'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${item['quantity'] ?? '0'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DropDownButton(
                          trailing: const Icon(FluentIcons.more, size: 16),
                          items: [
                            MenuFlyoutItem(
                              leading: Icon(FluentIcons.edit, size: 12),
                              text: const Text('Edit'),
                              onPressed: () => _editPickup(item),
                            ),
                            MenuFlyoutItem(
                              leading: Icon(FluentIcons.delete, size: 12),
                              text: const Text('Delete'),
                              onPressed: () => _deletePickup(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          // Empty State
          if (_filteredPickups.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      FluentIcons.package,
                      size: 48,
                      color: theme.resources.textFillColorDisabled,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No pickup records found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.resources.textFillColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Click 'Add Pickup' to schedule a new one.",
                      style: TextStyle(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Picked Up':
        color = Colors.green;
        break;
      case 'Cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
} // End of Class
