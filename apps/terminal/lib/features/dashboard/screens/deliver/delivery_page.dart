import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:terminal/core/constants/location_data.dart';
import 'package:terminal/core/widgets/form_widgets.dart';
import '../shared/trip_entry_scaffold.dart';

class DeliveryPage extends StatefulWidget {
  final bool isDialog;
  final Map<String, dynamic>? receiverData;

  const DeliveryPage({super.key, this.isDialog = false, this.receiverData});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  // Address & Contact Controllers
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  String _state = 'Ontario';
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Contact & Access
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();
  final _emailController = TextEditingController();
  final _gateCodeController = TextEditingController(); // New

  // Schedule & Reference
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    8,
    0,
  );
  DateTime _endTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    9,
    0,
  );

  final _poNumberController = TextEditingController(); // New
  final _deliveryNumberController = TextEditingController(); // New
  final _refNumberController = TextEditingController(); // Legacy/Search

  // App State
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _receivers = [];
  List<Map<String, dynamic>> _filteredReceivers = [];
  String _sortColumn = 'delivery_date';
  bool _isAscending = false;
  String _status = 'Scheduled';

  // Schedule & Logistics
  String _appointmentType = 'Live Unload';
  String _schedulingWindow = 'Strict Appointment';

  bool _driverAssist = false;
  bool _ppeRequired = false;
  bool _overnightParking = false;
  bool _strictLatePolicy = false;
  bool _callBeforeArrival = false;
  bool _lumperRequired = false;
  bool _gateCodeRequired = false; // Kept specific to receiver

  // New Flags matching Pickup
  bool _blindShipment = false;
  bool _scaleOnSite = false;
  bool _cleanTrailer = false;
  bool _hazmat = false;
  bool _facility247 = false;
  bool _strapsRequired = false;
  bool _liftgateRequired = false;
  bool _insideDelivery = false;
  bool _residential = false;
  bool _tempControl = false;
  bool _highValue = false;
  bool _teamRequired = false;
  bool _twicRequired = false;
  bool _noTouchFreight = false;

  // Cargo Details
  final _goodsController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController();
  final _linearFeetController = TextEditingController();
  final _cubeController = TextEditingController();
  final _trailerNumberController = TextEditingController();
  String _weightUnit = 'Lbs';

  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _searchController = TextEditingController();

  Offset _offset = Offset.zero;

  // Constants for Dropdowns (reused) removed.

  @override
  void initState() {
    super.initState();
    if (widget.receiverData != null) {
      _populateFields(widget.receiverData!);
    }
    if (!widget.isDialog) {
      _fetchReceivers();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _faxController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    _searchController.dispose();

    // New Disposes
    _gateCodeController.dispose();
    _poNumberController.dispose();
    _deliveryNumberController.dispose();
    _goodsController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    _linearFeetController.dispose();
    _cubeController.dispose();
    _trailerNumberController.dispose();

    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    _companyNameController.text = data['receiver_name'] ?? '';
    _addressController.text = data['address'] ?? '';
    _cityController.text = data['city'] ?? '';
    _state = data['state_province'] ?? 'Ontario';
    _zipCodeController.text = data['postal_code'] ?? '';
    _countryController.text = data['country'] ?? 'Canada';
    _contactController.text = data['contact_person'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _emailController.text = data['email'] ?? '';
    _faxController.text = data['fax'] ?? '';
    if (data['delivery_date'] != null) {
      _selectedDate = DateTime.parse(data['delivery_date']);
    }
    if (data['delivery_time'] != null) {
      final parts = data['delivery_time'].split(':');
      _startTime = DateTime(
        2000,
        1,
        1,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    if (data['end_time'] != null) {
      final parts = data['end_time'].split(':');
      _endTime = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    }

    _appointmentType = data['appointment_type'] ?? 'Live Unload';
    _schedulingWindow = data['scheduling_window'] ?? 'Strict Appointment';

    // References
    _refNumberController.text = data['reference_number'] ?? '';
    _poNumberController.text = data['po_number'] ?? '';
    _deliveryNumberController.text = data['delivery_number'] ?? '';
    _gateCodeController.text = data['gate_code'] ?? '';

    // Flags
    _ppeRequired = data['is_ppe_required'] ?? false;
    _driverAssist = data['is_driver_assist'] ?? false;
    _overnightParking = data['is_overnight_parking'] ?? false;
    _strictLatePolicy = data['is_strict_late_policy'] ?? false;
    _callBeforeArrival = data['is_call_before_arrival'] ?? false;
    _lumperRequired = data['is_lumper_required'] ?? false;
    _gateCodeRequired = data['is_gate_code_required'] ?? false;
    _blindShipment = data['is_blind_shipment'] ?? false;
    _scaleOnSite = data['is_scale_on_site'] ?? false;
    _cleanTrailer = data['is_clean_trailer'] ?? false;
    _hazmat = data['is_hazmat'] ?? false;
    _facility247 = data['is_facility_247'] ?? false;
    _strapsRequired = data['is_straps_required'] ?? false;
    _liftgateRequired = data['is_liftgate_required'] ?? false;
    _insideDelivery = data['is_inside_delivery'] ?? false;
    _residential = data['is_residential'] ?? false;
    _tempControl = data['is_temp_control'] ?? false;
    _highValue = data['is_high_value'] ?? false;
    _teamRequired = data['is_team_required'] ?? false;
    _twicRequired = data['is_twic_required'] ?? false;
    _noTouchFreight = data['is_no_touch_freight'] ?? false;

    // Cargo
    _goodsController.text = data['commodity'] ?? '';
    _weightController.text = (data['weight'] ?? '').toString();
    _weightUnit = data['weight_unit'] ?? 'Lbs';
    _quantityController.text = data['quantity'] ?? '';
    _linearFeetController.text = (data['linear_feet'] ?? '').toString();
    _cubeController.text = (data['cube'] ?? '').toString();
    _trailerNumberController.text = data['trailer_number'] ?? '';

    _notesController.text = data['driver_instructions'] ?? '';
    _internalNotesController.text = data['internal_notes'] ?? '';
    _status = data['status'] ?? 'Scheduled';
  }

  Future<void> _fetchReceivers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('receivers')
          .select()
          .order('delivery_date', ascending: false);

      if (mounted) {
        setState(() {
          _receivers = List<Map<String, dynamic>>.from(response);
          _filteredReceivers = _receivers;
          _sortReceivers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching receivers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReceivers = _receivers.where((item) {
        final name = (item['receiver_name'] ?? '').toLowerCase();
        final city = (item['city'] ?? '').toLowerCase();
        final ref = (item['reference_number'] ?? '').toLowerCase();
        return name.contains(query) ||
            city.contains(query) ||
            ref.contains(query);
      }).toList();
      _sortReceivers();
    });
  }

  void _sortReceivers() {
    _filteredReceivers.sort((a, b) {
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
      _sortReceivers();
    });
  }

  Future<void> _saveReceiver() async {
    if (_companyNameController.text.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Receiver name is required'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = {
        'receiver_name': _companyNameController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state_province': _state,
        'postal_code': _zipCodeController.text,
        'country': _countryController.text,
        'contact_person': _contactController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'fax': _faxController.text,
        'delivery_date': _selectedDate.toIso8601String().substring(0, 10),
        'delivery_time':
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        'end_time': _schedulingWindow != 'Strict Appointment'
            ? '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00'
            : null,
        'appointment_type': _appointmentType,
        'scheduling_window': _schedulingWindow,
        'reference_number': _refNumberController.text,
        'po_number': _poNumberController.text,
        'delivery_number': _deliveryNumberController.text,
        'gate_code': _gateCodeController.text,
        'trailer_number': _trailerNumberController.text,

        'is_ppe_required': _ppeRequired,
        'is_driver_assist': _driverAssist,
        'is_overnight_parking': _overnightParking,
        'is_strict_late_policy': _strictLatePolicy,
        'is_call_before_arrival': _callBeforeArrival,
        'is_lumper_required': _lumperRequired,
        'is_gate_code_required': _gateCodeRequired,
        'is_blind_shipment': _blindShipment,
        'is_scale_on_site': _scaleOnSite,
        'is_clean_trailer': _cleanTrailer,
        'is_hazmat': _hazmat,
        'is_facility_247': _facility247,
        'is_straps_required': _strapsRequired,
        'is_liftgate_required': _liftgateRequired,
        'is_inside_delivery': _insideDelivery,
        'is_residential': _residential,
        'is_temp_control': _tempControl,
        'is_high_value': _highValue,
        'is_team_required': _teamRequired,
        'is_twic_required': _twicRequired,
        'is_no_touch_freight': _noTouchFreight,

        'commodity': _goodsController.text,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'weight_unit': _weightUnit,
        'quantity': _quantityController.text,
        'linear_feet': double.tryParse(_linearFeetController.text),
        'cube': double.tryParse(_cubeController.text),

        'driver_instructions': _notesController.text,
        'internal_notes': _internalNotesController.text,
        'status': _status,
      };

      if (widget.receiverData != null) {
        await Supabase.instance.client
            .from('receivers')
            .update(data)
            .eq('id', widget.receiverData!['id']);
      } else {
        await Supabase.instance.client.from('receivers').insert(data);
      }

      if (mounted) {
        if (widget.isDialog) {
          Navigator.pop(context, true);
        } else {
          _fetchReceivers();
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      debugPrint('Error saving receiver: $e');
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text('Error saving record: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteReceiver(String id) async {
    try {
      await Supabase.instance.client.from('receivers').delete().eq('id', id);
      _fetchReceivers();
    } catch (e) {
      debugPrint('Error deleting receiver: $e');
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 16, top: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FluentTheme.of(context).resources.textFillColorSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (widget.isDialog) {
      return Transform.translate(
        offset: _offset,
        child: ContentDialog(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 900),
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
                      widget.receiverData == null
                          ? 'Add New Receiver'
                          : 'Edit Receiver',
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
                onPressed: _isSaving ? null : _saveReceiver,
                child: _isSaving
                    ? const ProgressRing(strokeWidth: 2.5)
                    : const Text('Save Record'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: FACILITY & REFERENCES
                _buildSectionHeader('Facility & References'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: FluentLabeledInput(
                        label: 'Facility Name',
                        controller: _companyNameController,
                        placeholder: 'Enter facility name',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'Internal Code / ID',
                        controller: _refNumberController,
                        placeholder: 'Plant ID etc.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'PO Number',
                        controller: _poNumberController,
                        placeholder: 'PO #',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'Delivery Number',
                        controller: _deliveryNumberController,
                        placeholder: 'DEL #',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'Gate Code',
                        controller: _gateCodeController,
                        placeholder: 'Optional',
                      ),
                    ),
                  ],
                ),

                // SECTION 2: LOCATION & ADDRESS
                _buildSectionHeader('Location & Address'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'Address',
                        controller: _addressController,
                        placeholder: 'Street address',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'City',
                        controller: _cityController,
                        placeholder: 'City',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 2, bottom: 6),
                            child: Text(
                              'State / Province',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ComboBox<String>(
                            value: _state,
                            placeholder: const Text('Select State'),
                            items: [
                              ...LocationData.canadianProvinces.entries.map(
                                (e) => ComboBoxItem(
                                  value: e.key,
                                  child: Text("${e.key} - ${e.value}"),
                                ),
                              ),
                              ...LocationData.usStates.entries.map(
                                (e) => ComboBoxItem(
                                  value: e.key,
                                  child: Text("${e.key} - ${e.value}"),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _state = v);
                            },
                            isExpanded: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Zip / Postal',
                        controller: _zipCodeController,
                        placeholder: 'Code',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(
                              () => _countryController.text = v ?? 'Canada',
                            ),
                            isExpanded: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // SECTION 3: CONTACT
                _buildSectionHeader('Contact Information'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FluentLabeledInput(
                        label: 'Contact Person',
                        controller: _contactController,
                        placeholder: 'Name',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Phone',
                        controller: _phoneController,
                        placeholder: '(555) 123-4567',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Email',
                        controller: _emailController,
                        placeholder: 'contact@email.com',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Fax',
                        controller: _faxController,
                        placeholder: 'Optional',
                      ),
                    ),
                  ],
                ),

                // SECTION 4: SCHEDULE
                _buildSectionHeader('SCHEDULE'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: _schedulingWindow == 'Strict Appointment' ? 3 : 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Window',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ComboBox<String>(
                            value: _schedulingWindow,
                            items:
                                [
                                      'Strict Appointment',
                                      'FCFS',
                                      'Window (2hr)',
                                      'Window (4hr)',
                                    ]
                                    .map(
                                      (e) => ComboBoxItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(
                              () =>
                                  _schedulingWindow = v ?? 'Strict Appointment',
                            ),
                            isExpanded: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: _schedulingWindow == 'Strict Appointment' ? 3 : 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DatePicker(
                            selected: _selectedDate,
                            onChanged: (v) => setState(() => _selectedDate = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TimePicker(
                            selected: _startTime,
                            onChanged: (v) => setState(() => _startTime = v),
                            hourFormat: HourFormat.HH,
                          ),
                        ],
                      ),
                    ),
                    if (_schedulingWindow != 'Strict Appointment') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TimePicker(
                              selected: _endTime,
                              onChanged: (v) => setState(() => _endTime = v),
                              hourFormat: HourFormat.HH,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: _schedulingWindow == 'Strict Appointment' ? 3 : 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Type',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ComboBox<String>(
                                  value: _appointmentType,
                                  items: ['Live Unload', 'Drop Trailer']
                                      .map(
                                        (e) => ComboBoxItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _appointmentType = v ?? 'Live Unload',
                                  ),
                                  isExpanded: true,
                                ),
                              ],
                            ),
                          ),
                          if (_appointmentType == 'Drop Trailer') ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: FluentLabeledInput(
                                label: 'Trailer #',
                                controller: _trailerNumberController,
                                placeholder: 'Trlr #',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // SECTION 5: CARGO & SPECS
                _buildSectionHeader('CARGO & SPECS'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 4,
                      child: FluentLabeledInput(
                        label: 'Commodity',
                        controller: _goodsController,
                        placeholder: 'e.g. Auto Parts',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: FluentLabeledInput(
                        label: 'Qty',
                        controller: _quantityController,
                        placeholder: 'Skids',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ComboBox<String>(
                            value: _weightUnit,
                            items: ['Lbs', 'Kgs']
                                .map(
                                  (e) => ComboBoxItem(value: e, child: Text(e)),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _weightUnit = v ?? 'Lbs'),
                            isExpanded: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: FluentLabeledInput(
                        label: 'Weight ($_weightUnit)',
                        controller: _weightController,
                        placeholder: '0.0',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: FluentLabeledInput(
                        label: 'Lin Ft',
                        controller: _linearFeetController,
                        placeholder: '53',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: FluentLabeledInput(
                        label: 'Cube',
                        controller: _cubeController,
                        placeholder: '0',
                      ),
                    ),
                  ],
                ),

                // SECTION 6: NOTES & FLAGS
                _buildSectionHeader('Logistics & Instructions'),
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
                      label: 'Overnight Pkg',
                      icon: FluentIcons.parking_location,
                      value: _overnightParking,
                      onChanged: (v) => setState(() => _overnightParking = v),
                    ),
                    FluentOptionChip(
                      label: 'Strict Policy',
                      icon: FluentIcons.timer,
                      value: _strictLatePolicy,
                      onChanged: (v) => setState(() => _strictLatePolicy = v),
                    ),
                    FluentOptionChip(
                      label: 'Call Before',
                      icon: FluentIcons.phone,
                      value: _callBeforeArrival,
                      onChanged: (v) => setState(() => _callBeforeArrival = v),
                    ),
                    FluentOptionChip(
                      label: 'Lumper Req.',
                      icon: FluentIcons.money,
                      value: _lumperRequired,
                      onChanged: (v) => setState(() => _lumperRequired = v),
                    ),
                    FluentOptionChip(
                      label: 'Gate Code',
                      icon: FluentIcons.lock,
                      value: _gateCodeRequired,
                      onChanged: (v) => setState(() => _gateCodeRequired = v),
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
                      label: 'Liftgate Req.',
                      icon: FluentIcons.chevron_down,
                      value: _liftgateRequired,
                      onChanged: (v) => setState(() => _liftgateRequired = v),
                    ),
                    FluentOptionChip(
                      label: 'Inside Deliv.',
                      icon: FluentIcons.door,
                      value: _insideDelivery,
                      onChanged: (v) => setState(() => _insideDelivery = v),
                    ),
                    FluentOptionChip(
                      label: 'Residential',
                      icon: FluentIcons.home,
                      value: _residential,
                      onChanged: (v) => setState(() => _residential = v),
                    ),
                    FluentOptionChip(
                      label: 'Temp Control',
                      icon: FluentIcons.snowflake,
                      value: _tempControl,
                      onChanged: (v) => setState(() => _tempControl = v),
                    ),
                    FluentOptionChip(
                      label: 'High Value',
                      icon: FluentIcons.diamond,
                      value: _highValue,
                      onChanged: (v) => setState(() => _highValue = v),
                    ),
                    FluentOptionChip(
                      label: 'Team Req.',
                      icon: FluentIcons.group,
                      value: _teamRequired,
                      onChanged: (v) => setState(() => _teamRequired = v),
                    ),
                    FluentOptionChip(
                      label: 'TWIC/Port',
                      icon: FluentIcons.location,
                      value: _twicRequired,
                      onChanged: (v) => setState(() => _twicRequired = v),
                    ),
                    FluentOptionChip(
                      label: 'No Touch',
                      icon: FluentIcons.contact_info,
                      value: _noTouchFreight,
                      onChanged: (v) => setState(() => _noTouchFreight = v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Driver Instructions (Visible in Mobile App)',
                        controller: _notesController,
                        maxLines: 3,
                        placeholder: 'Enter instructions for the driver...',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FluentLabeledInput(
                        label: 'Internal Office Notes',
                        controller: _internalNotesController,
                        maxLines: 3,
                        placeholder: 'Dispatch/Broker notes...',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    // MAIN PAGE VIEW
    return TripEntryScaffold(
      title: 'Receiver Management',
      actions: [
        FilledButton(
          onPressed: () => _openReceiverDialog(context),
          child: const Row(
            children: [
              Icon(FluentIcons.add, size: 12),
              SizedBox(width: 8),
              Text('Add Receiver'),
            ],
          ),
        ),
      ],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsRow(theme),
              const SizedBox(height: 24),
              _buildSearchHeader(theme),
              const SizedBox(height: 16),
              _buildReceiversSection(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(FluentThemeData theme) {
    return Row(
      children: [
        _buildStatCard(
          'Total Receivers',
          _receivers.length.toString(),
          FluentIcons.delivery_truck,
          theme.accentColor,
          theme,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Scheduled Today',
          _receivers
              .where((e) {
                final date = e['delivery_date'];
                if (date == null) return false;
                final nowString = DateTime.now().toIso8601String().substring(
                  0,
                  10,
                );
                return date == nowString;
              })
              .length
              .toString(),
          FluentIcons.calendar,
          Colors.orange,
          theme,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Delivered',
          _receivers.where((e) => e['status'] == 'Delivered').length.toString(),
          FluentIcons.check_mark,
          Colors.green,
          theme,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    FluentThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
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

  Widget _buildSearchHeader(FluentThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: _searchController,
            placeholder:
                'Search by receiver name, city, or reference number...',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(FluentIcons.search),
            ),
            decoration: WidgetStatePropertyAll(
              BoxDecoration(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiversSection(BuildContext context, FluentThemeData theme) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_filteredReceivers.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              FluentIcons.search_and_apps,
              size: 40,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No receivers found',
              style: TextStyle(color: theme.resources.textFillColorSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        children: [
          _buildTableHeader(theme),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredReceivers.length,
            separatorBuilder: (context, index) => Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            itemBuilder: (context, index) =>
                _buildReceiverRow(_filteredReceivers[index], index + 1, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: _buildSortableHeader('Seq', 'created_at', theme),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildSortableHeader('Status', 'status', theme),
          ),
          Expanded(
            flex: 3,
            child: _buildSortableHeader('Receiver', 'receiver_name', theme),
          ),
          Expanded(flex: 2, child: _buildSortableHeader('City', 'city', theme)),
          Expanded(
            flex: 2,
            child: _buildSortableHeader('Reference', 'reference_number', theme),
          ),
          Expanded(
            flex: 2,
            child: _buildSortableHeader('Date', 'delivery_date', theme),
          ),
          const SizedBox(width: 80), // Actions
        ],
      ),
    );
  }

  Widget _buildSortableHeader(
    String title,
    String column,
    FluentThemeData theme,
  ) {
    final isSelected = _sortColumn == column;
    return GestureDetector(
      onTap: () => _onHeaderTap(column),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.accentColor
                    : theme.resources.textFillColorPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _isAscending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down,
                size: 10,
                color: theme.accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverRow(
    Map<String, dynamic> item,
    int seq,
    FluentThemeData theme,
  ) {
    return HoverButton(
      onPressed: () => _openReceiverDialog(context, receiverData: item),
      builder: (context, states) {
        return Container(
          color: states.isHovered
              ? theme.resources.subtleFillColorTertiary
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  seq.toString(),
                  style: TextStyle(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildStatusBadge(item['status'] ?? 'Scheduled', theme),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['receiver_name'] ?? 'N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.resources.textFillColorPrimary,
                      ),
                    ),
                    Text(
                      item['address'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item['city'] ?? 'N/A',
                  style: TextStyle(color: theme.resources.textFillColorPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item['reference_number'] ?? '-',
                  style: TextStyle(color: theme.resources.textFillColorPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item['delivery_date'] ?? '-',
                  style: TextStyle(color: theme.resources.textFillColorPrimary),
                ),
              ),
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.edit, size: 14),
                      onPressed: () =>
                          _openReceiverDialog(context, receiverData: item),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.delete, size: 14),
                      onPressed: () => _showDeleteDialog(item),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, FluentThemeData theme) {
    Color color;
    switch (status) {
      case 'Delivered':
        color = Colors.green;
        break;
      case 'Cancelled':
        color = Colors.red;
        break;
      default:
        color = theme.accentColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  void _openReceiverDialog(
    BuildContext context, {
    Map<String, dynamic>? receiverData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          DeliveryPage(isDialog: true, receiverData: receiverData),
    ).then((value) {
      if (value == true) {
        _fetchReceivers();
      }
    });
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Receiver?'),
        content: Text(
          'Are you sure you want to delete ${item['receiver_name']}?',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _deleteReceiver(item['id']);
            },
          ),
        ],
      ),
    );
  }
}
