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
  // Removed unused _stateController
  String _state = 'Ontario';
  final _cityController = TextEditingController();
  // Removed unused _unitController
  final _zipCodeController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _refNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _searchController = TextEditingController();

  // Schedule & Flags
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    8,
    0,
  );
  String _status = 'Scheduled';
  String _appointmentType = 'Live Unload';
  String _schedulingWindow = 'Strict Appointment';

  bool _driverAssist = false;
  bool _ppeRequired = false;
  bool _overnightParking = false;
  bool _strictLatePolicy = false;
  bool _callBeforeArrival = false;
  bool _lumperRequired = false;
  bool _gateCodeRequired = false;

  // App State
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _receivers = [];
  List<Map<String, dynamic>> _filteredReceivers = [];
  String _sortColumn = 'delivery_date';
  bool _isAscending = false;

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
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    _appointmentType = data['appointment_type'] ?? 'Live Unload';
    _schedulingWindow = data['scheduling_window'] ?? 'Strict Appointment';
    _refNumberController.text = data['reference_number'] ?? '';
    _ppeRequired = data['is_ppe_required'] ?? false;
    _driverAssist = data['is_driver_assist'] ?? false;
    _overnightParking = data['is_overnight_parking'] ?? false;
    _strictLatePolicy = data['is_strict_late_policy'] ?? false;
    _callBeforeArrival = data['is_call_before_arrival'] ?? false;
    _lumperRequired = data['is_lumper_required'] ?? false;
    _gateCodeRequired = data['is_gate_code_required'] ?? false;
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
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'appointment_type': _appointmentType,
        'scheduling_window': _schedulingWindow,
        'reference_number': _refNumberController.text,
        'is_ppe_required': _ppeRequired,
        'is_driver_assist': _driverAssist,
        'is_overnight_parking': _overnightParking,
        'is_strict_late_policy': _strictLatePolicy,
        'is_call_before_arrival': _callBeforeArrival,
        'is_lumper_required': _lumperRequired,
        'is_gate_code_required': _gateCodeRequired,
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
      if (mounted) setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

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
                    ? const ProgressRing(strokeWidth: 2)
                    : const Text('Save Record'),
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
                      // Section: Receiver Location
                      const FluentSectionHeader(title: 'Receiver Location'),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Receiver Company Name',
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
                                const Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 6),
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
                                  'Delivery Date',
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
                                  'Appointment Time',
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
                                  items: ['Scheduled', 'Delivered', 'Cancelled']
                                      .map(
                                        (e) => ComboBoxItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
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
                      const SizedBox(height: 16),
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
                                              child: Text(e),
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
                      FluentLabeledInput(
                        label: 'Reference Numbers',
                        controller: _refNumberController,
                        placeholder: 'DEL #, REF #',
                      ),

                      const SizedBox(height: 24),
                      const FluentSectionHeader(
                        title: 'Logistics Flags',
                        showDivider: true,
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
                            label: 'Strict Policy',
                            icon: FluentIcons.timer,
                            value: _strictLatePolicy,
                            onChanged: (v) =>
                                setState(() => _strictLatePolicy = v),
                          ),
                          FluentOptionChip(
                            label: 'Call Before',
                            icon: FluentIcons.phone,
                            value: _callBeforeArrival,
                            onChanged: (v) =>
                                setState(() => _callBeforeArrival = v),
                          ),
                          FluentOptionChip(
                            label: 'Lumper Req.',
                            icon: FluentIcons.money,
                            value: _lumperRequired,
                            onChanged: (v) =>
                                setState(() => _lumperRequired = v),
                          ),
                          FluentOptionChip(
                            label: 'Gate Code',
                            icon: FluentIcons.lock,
                            value: _gateCodeRequired,
                            onChanged: (v) =>
                                setState(() => _gateCodeRequired = v),
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
                        placeholder: 'Visibility to Driver',
                      ),
                      const SizedBox(height: 16),
                      FluentLabeledInput(
                        label: 'Internal Warehouse Notes',
                        controller: _internalNotesController,
                        maxLines: 3,
                        placeholder: 'Dispatch Visibility Only',
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
