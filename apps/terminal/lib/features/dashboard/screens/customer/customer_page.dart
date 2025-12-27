import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/trip_entry_scaffold.dart';
import 'package:terminal/core/constants/location_data.dart';
import 'package:terminal/core/widgets/form_widgets.dart';

class CustomerPage extends StatefulWidget {
  final bool isDialog;
  final Map<String, dynamic>? customerData;
  const CustomerPage({super.key, this.isDialog = false, this.customerData});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  // Form Controllers - Core fields
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Order fields
  final _orderController = TextEditingController();
  final _referenceController = TextEditingController();
  final _rateController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  String _currency = 'CDN';
  String? _selectedEquipment = 'Dry Van';
  String? _selectedDispatcher;
  List<String> _staffList = [];

  // Notes
  final _notesController = TextEditingController();

  // Search & Filter
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCustomers = [];

  // Shipment Flags
  bool _roundTrip = false;
  bool _bookedForOtherCarriers = false;
  bool _csaFastLoad = false;
  bool _bondedShipment = false;
  bool _dangerousHazmat = false;
  bool _highPriorityLoad = false;
  bool _teamLoad = false;
  bool _tarpRequired = false;
  bool _appointmentRequired = false;
  bool _liftgateNeeded = false;
  bool _residentialDelivery = false;
  bool _driverAssist = false;
  bool _dropTrailer = false;
  bool _portRail = false;
  bool _nonStackable = false;
  bool _fragile = false;

  // Data state
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // Sorting
  String _sortColumn = 'name';
  bool _isAscending = true;

  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
    _fetchCustomers();
    _searchController.addListener(_onSearchChanged);

    if (widget.customerData != null) {
      _populateFields(widget.customerData!);
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _customerNameController.text = data['name'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _faxController.text = data['fax'] ?? '';
    _emailController.text = data['email'] ?? '';
    _addressController.text = data['address_line1'] ?? '';
    _cityController.text = data['city'] ?? '';
    _stateController.text = data['state_province'] ?? '';
    _zipCodeController.text = data['postal_code'] ?? '';
    _countryController.text = data['country'] ?? 'Canada';
    _orderController.text = data['order_number'] ?? '';
    _referenceController.text = data['reference_numbers'] ?? '';
    _rateController.text = (data['rate'] ?? 0.0).toString();
    _currency = data['currency'] ?? 'CDN';
    _paymentTermsController.text = data['payment_terms'] ?? '';
    _selectedEquipment = data['equipment_type'] ?? 'Dry Van';
    _selectedDispatcher = data['assigned_dispatcher'];
    _notesController.text = data['notes'] ?? '';

    _roundTrip = data['is_round_trip'] ?? false;
    _bookedForOtherCarriers = data['is_booked_for_other_carriers'] ?? false;
    _csaFastLoad = data['is_csa_fast_load'] ?? false;
    _bondedShipment = data['is_bonded_shipment'] ?? false;
    _dangerousHazmat = data['is_hazmat'] ?? false;
    _highPriorityLoad = data['is_high_priority'] ?? false;
    _teamLoad = data['is_team_load'] ?? false;
    _tarpRequired = data['is_tarp_required'] ?? false;
    _appointmentRequired = data['is_appointment_required'] ?? false;
    _liftgateNeeded = data['is_liftgate_needed'] ?? false;
    _residentialDelivery = data['is_residential_delivery'] ?? false;
    _driverAssist = data['is_driver_assist'] ?? false;
    _dropTrailer = data['is_drop_trailer'] ?? false;
    _portRail = data['is_port_rail'] ?? false;
    _nonStackable = data['is_non_stackable'] ?? false;
    _fragile = data['is_fragile'] ?? false;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _customerNameController.dispose();
    _phoneController.dispose();
    _faxController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _orderController.dispose();
    _referenceController.dispose();
    _rateController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _applySort();
    });
  }

  void _applySort() {
    _filteredCustomers.sort((a, b) {
      final aValue = a[_sortColumn]?.toString().toLowerCase() ?? '';
      final bValue = b[_sortColumn]?.toString().toLowerCase() ?? '';
      return _isAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        final name = (customer['name'] ?? '').toLowerCase();
        final city = (customer['city'] ?? '').toLowerCase();
        final email = (customer['email'] ?? '').toLowerCase();
        return name.contains(query) ||
            city.contains(query) ||
            email.contains(query);
      }).toList();
      _applySort();
    });
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(response);
          _filteredCustomers = _customers;
          _applySort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, id')
          .eq('id', currentUserId)
          .single();

      final String? name = response['full_name'] as String?;
      if (mounted && name != null && name.isNotEmpty) {
        setState(() {
          _staffList = [name];
          _selectedDispatcher = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      if (mounted && _staffList.isEmpty) {
        setState(() {
          _staffList = ['Maninder Singh'];
          _selectedDispatcher = 'Maninder Singh';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    if (widget.isDialog) {
      return Transform.translate(
        offset: _offset,
        child: ContentDialog(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
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
                      widget.customerData == null
                          ? 'Add New Customer'
                          : 'Edit Customer',
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
                onPressed: _isSaving ? null : _saveRecord,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('Save Record'),
              ),
            ],
          ),
          content: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(child: _buildFormContent(isLight)),
              ),
            ],
          ),
        ),
      );
    }

    return TripEntryScaffold(
      title: 'Customers',
      actions: [
        FilledButton(
          onPressed: () => _openAddCustomerDialog(context),
          child: const Row(
            children: [
              Icon(FluentIcons.add, size: 12),
              SizedBox(width: 8),
              Text('Add Customer'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsRow(isLight),
              const SizedBox(height: 24),
              _buildSearchHeader(isLight),
              const SizedBox(height: 16),
              _buildCustomerList(isLight),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const CustomerPage(isDialog: true),
    ).then((_) => _fetchCustomers());
  }

  void _editCustomer(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          CustomerPage(isDialog: true, customerData: customer),
    ).then((_) => _fetchCustomers());
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer['name']}? This action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, 'cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (result == 'delete') {
      try {
        await Supabase.instance.client
            .from('customers')
            .delete()
            .eq('id', customer['id']);

        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Customer deleted successfully'),
              severity: InfoBarSeverity.success,
              onClose: close,
            ),
          );
          _fetchCustomers();
        }
      } catch (e) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: Text('Error deleting customer: $e'),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatsRow(bool isLight) {
    final highPriorityCount = _customers
        .where((c) => c['is_high_priority'] == true)
        .length;
    final usaCount = _customers.where((c) => c['country'] == 'USA').length;

    return Row(
      children: [
        _buildStatCard(
          'Total Customers',
          _customers.length.toString(),
          FluentIcons.people,
          isLight,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'High Priority',
          highPriorityCount.toString(),
          FluentIcons.incident_triangle,
          isLight,
          color: Colors.orange,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'USA Clients',
          usaCount.toString(),
          FluentIcons.map_pin,
          isLight,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    bool isLight, {
    Color? color,
  }) {
    final theme = FluentTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (color ?? theme.accentColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color ?? theme.accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isLight) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(FluentIcons.search, size: 14, color: Colors.grey),
                ),
                Expanded(
                  child: TextBox(
                    controller: _searchController,
                    placeholder: 'Search customers by name, city or email...',
                    decoration: const WidgetStatePropertyAll(
                      BoxDecoration(color: Colors.transparent),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(FluentIcons.clear, size: 12),
                    onPressed: () => _searchController.clear(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerList(bool isLight) {
    final theme = FluentTheme.of(context);
    if (_isLoading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(40.0), child: ProgressRing()),
      );
    }

    if (_filteredCustomers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(FluentIcons.people, size: 64, color: Colors.grey[40]),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isEmpty
                  ? 'No customers found'
                  : 'No results found',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'Get started by creating your first customer record.'
                  : 'Try adjusting your search query.',
              style: TextStyle(color: theme.resources.textFillColorSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableHeader(isLight),
          const Divider(),
          ..._filteredCustomers.map(
            (customer) => _buildCustomerRow(customer, isLight),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isLight) {
    final theme = FluentTheme.of(context);
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: theme.resources.textFillColorSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildSortableHeader('CUSTOMER INFO', 'name', style),
          ),
          Expanded(
            flex: 2,
            child: _buildSortableHeader('LOCATION', 'city', style),
          ),
          Expanded(
            flex: 2,
            child: _buildSortableHeader(
              'DISPATCHER',
              'assigned_dispatcher',
              style,
            ),
          ),
          Expanded(flex: 2, child: Text('LOGISTICS FLAGS', style: style)),
          SizedBox(
            width: 80,
            child: Text('ACTIONS', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String label, String column, TextStyle style) {
    final isSorted = _sortColumn == column;
    return GestureDetector(
      onTap: () => _toggleSort(column),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _isAscending ? FluentIcons.chevron_up : FluentIcons.chevron_down,
              size: 8,
              color: FluentTheme.of(context).accentColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> customer, bool isLight) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          // Customer Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      customer['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (customer['is_high_priority'] == true) ...[
                      const SizedBox(width: 8),
                      _buildPropertyBadge('PRIORITY', Colors.orange, isLight),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  customer['email'] ?? customer['phone'] ?? '-',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Location
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['city'] ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${customer['state_province'] ?? ''}, ${customer['country'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Dispatcher
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.contact,
                        size: 12,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        customer['assigned_dispatcher'] ?? 'Unassigned',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Flags
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (customer['is_hazmat'] == true)
                  _buildPropertyBadge('HAZ', Colors.red, isLight),
                if (customer['is_bonded_shipment'] == true)
                  _buildPropertyBadge('BONDED', Colors.blue, isLight),
                if (customer['is_csa_fast_load'] == true)
                  _buildPropertyBadge('FAST', Colors.green, isLight),
                if (customer['equipment_type'] != null)
                  _buildPropertyBadge(
                    customer['equipment_type'].toString().toUpperCase(),
                    theme.resources.textFillColorSecondary,
                    isLight,
                  ),
              ],
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.edit, size: 14),
                  onPressed: () => _editCustomer(customer),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete, size: 14),
                  onPressed: () => _deleteCustomer(customer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyBadge(String label, Color color, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Contact Details
        // Section: Contact Details
        const FluentSectionHeader(title: 'Contact details'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FluentLabeledInput(
                label: 'Customer Name',
                controller: _customerNameController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FluentLabeledInput(
                label: 'Phone',
                controller: _phoneController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FluentLabeledInput(
                label: 'Email',
                controller: _emailController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FluentLabeledInput(
                label: 'Fax',
                controller: _faxController,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const FluentSectionHeader(title: 'Address details', showDivider: true),
        const SizedBox(height: 20),
        FluentLabeledInput(
          label: 'Street Address',
          controller: _addressController,
        ),
        const SizedBox(height: 20),
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
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'State/Prov',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            FluentTheme.of(context).brightness ==
                                Brightness.light
                            ? Colors.grey[140]
                            : Colors.grey[80],
                      ),
                    ),
                  ),
                  ComboBox<String>(
                    value: _stateController.text.isEmpty
                        ? null
                        : _stateController.text,
                    placeholder: const Text(
                      'Select...',
                      style: TextStyle(fontSize: 14),
                    ),
                    items: [
                      // Canada
                      ...LocationData.canadianProvinces.entries.map(
                        (e) => ComboBoxItem(
                          value: '${e.key} - ${e.value}',
                          child: Text(
                            '${e.key} - ${e.value}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      // USA
                      ...LocationData.usStates.entries.map(
                        (e) => ComboBoxItem(
                          value: '${e.key} - ${e.value}',
                          child: Text(
                            '${e.key} - ${e.value}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _stateController.text = v ?? ''),
                    isExpanded: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: FluentLabeledInput(
                label: 'Zip Code',
                controller: _zipCodeController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildDropdown(
                'Country',
                _countryController.text.isEmpty
                    ? 'Canada'
                    : _countryController.text,
                LocationData.countries,
                (v) => setState(() => _countryController.text = v ?? 'Canada'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const FluentSectionHeader(
          title: 'Order & Logistics',
          showDivider: true,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdown(
                'Assigned Dispatcher',
                _selectedDispatcher,
                _staffList,
                (v) => setState(() => _selectedDispatcher = v),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FluentLabeledInput(
                label: 'Order Number',
                controller: _orderController,
              ),
            ),
            const SizedBox(width: 24),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ToggleSwitch(
                checked: _highPriorityLoad,
                onChanged: (v) => setState(() => _highPriorityLoad = v),
                content: const Text('High Priority'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Equipment Type',
                _selectedEquipment,
                ['Dry Van', 'Reefer', 'Flatbed', 'Step Deck', 'Roll Tight'],
                (v) => setState(() => _selectedEquipment = v),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: FluentLabeledInput(
                label: 'Reference Numbers',
                controller: _referenceController,
                placeholder: 'PO, BOL, Pickup #',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: FluentLabeledInput(
                label: 'Rate',
                controller: _rateController,
              ),
            ),
            const SizedBox(width: 24),
            _buildCurrencyToggle(isLight),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: FluentLabeledInput(
                label: 'Payment Terms',
                controller: _paymentTermsController,
                placeholder: 'e.g. Net 30',
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const FluentSectionHeader(title: 'Additional flags', showDivider: true),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FluentOptionChip(
              label: 'Round Trip',
              value: _roundTrip,
              icon: FluentIcons.repeat_all,
              onChanged: (v) => setState(() => _roundTrip = v),
            ),
            FluentOptionChip(
              label: 'Other Carriers',
              value: _bookedForOtherCarriers,
              icon: FluentIcons.account_management,
              onChanged: (v) => setState(() => _bookedForOtherCarriers = v),
            ),
            FluentOptionChip(
              label: 'CSA/FAST',
              value: _csaFastLoad,
              icon: FluentIcons.verified_brand,
              onChanged: (v) => setState(() => _csaFastLoad = v),
            ),
            FluentOptionChip(
              label: 'Bonded Load',
              value: _bondedShipment,
              icon: FluentIcons.lock,
              onChanged: (v) => setState(() => _bondedShipment = v),
            ),
            FluentOptionChip(
              label: 'Hazmat',
              value: _dangerousHazmat,
              icon: FluentIcons.warning,
              onChanged: (v) => setState(() => _dangerousHazmat = v),
            ),
            FluentOptionChip(
              label: 'Team Load',
              value: _teamLoad,
              icon: FluentIcons.people,
              onChanged: (v) => setState(() => _teamLoad = v),
            ),
            FluentOptionChip(
              label: 'Tarp Required',
              value: _tarpRequired,
              icon: FluentIcons.all_apps,
              onChanged: (v) => setState(() => _tarpRequired = v),
            ),
            FluentOptionChip(
              label: 'Appointment Req',
              value: _appointmentRequired,
              icon: FluentIcons.calendar,
              onChanged: (v) => setState(() => _appointmentRequired = v),
            ),
            FluentOptionChip(
              label: 'Liftgate Needed',
              value: _liftgateNeeded,
              icon: FluentIcons.up,
              onChanged: (v) => setState(() => _liftgateNeeded = v),
            ),
            FluentOptionChip(
              label: 'Residential',
              value: _residentialDelivery,
              icon: FluentIcons.home,
              onChanged: (v) => setState(() => _residentialDelivery = v),
            ),
            FluentOptionChip(
              label: 'Driver Assist',
              value: _driverAssist,
              icon: FluentIcons.customer_assets,
              onChanged: (v) => setState(() => _driverAssist = v),
            ),
            FluentOptionChip(
              label: 'Drop Trailer',
              value: _dropTrailer,
              icon: FluentIcons.down,
              onChanged: (v) => setState(() => _dropTrailer = v),
            ),
            FluentOptionChip(
              label: 'Port/Rail',
              value: _portRail,
              icon: FluentIcons.product,
              onChanged: (v) => setState(() => _portRail = v),
            ),
            FluentOptionChip(
              label: 'Non-Stackable',
              value: _nonStackable,
              icon: FluentIcons.stop,
              onChanged: (v) => setState(() => _nonStackable = v),
            ),
            FluentOptionChip(
              label: 'Fragile',
              value: _fragile,
              icon: FluentIcons.diamond,
              onChanged: (v) => setState(() => _fragile = v),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const FluentSectionHeader(
          title: 'Special instructions & Notes',
          showDivider: true,
        ),
        const SizedBox(height: 16),
        FluentLabeledInput(
          label: 'Instructions',
          controller: _notesController,
          maxLines: 4,
          placeholder:
              'Add any specific instructions for the driver or office...',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCurrencyToggle(bool isLight) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'CURRENCY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCurrencyButton('USD', isLight),
              const SizedBox(width: 2),
              _buildCurrencyButton('CDN', isLight),
            ],
          ),
        ),

        // Add a bottom border spacer to match the underline field height exactly
      ],
    );
  }

  Widget _buildCurrencyButton(String currency, bool isLight) {
    final theme = FluentTheme.of(context);
    final isSelected = _currency == currency;
    return GestureDetector(
      onTap: () => setState(() => _currency = currency),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? FluentTheme.of(context).accentColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          currency,
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

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ComboBox<String>(
            value: value,
            placeholder: const Text(
              'Select...',
              style: TextStyle(fontSize: 15),
            ),
            items: items
                .map((e) => ComboBoxItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Future<void> _saveRecord() async {
    if (_customerNameController.text.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Name is required'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'name': _customerNameController.text,
        'phone': _phoneController.text,
        'fax': _faxController.text,
        'email': _emailController.text,
        'address_line1': _addressController.text,
        'city': _cityController.text,
        'state_province': _stateController.text,
        'postal_code': _zipCodeController.text,
        'country': _countryController.text,
        'order_number': _orderController.text,
        'reference_numbers': _referenceController.text,
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'currency': _currency,
        'payment_terms': _paymentTermsController.text,
        'equipment_type': _selectedEquipment,
        'assigned_dispatcher': _selectedDispatcher,
        'is_round_trip': _roundTrip,
        'is_booked_for_other_carriers': _bookedForOtherCarriers,
        'is_csa_fast_load': _csaFastLoad,
        'is_bonded_shipment': _bondedShipment,
        'is_hazmat': _dangerousHazmat,
        'is_high_priority': _highPriorityLoad,
        'is_team_load': _teamLoad,
        'is_tarp_required': _tarpRequired,
        'is_appointment_required': _appointmentRequired,
        'is_liftgate_needed': _liftgateNeeded,
        'is_residential_delivery': _residentialDelivery,
        'is_driver_assist': _driverAssist,
        'is_drop_trailer': _dropTrailer,
        'is_port_rail': _portRail,
        'is_non_stackable': _nonStackable,
        'is_fragile': _fragile,
        'notes': _notesController.text,
      };

      if (widget.customerData != null) {
        await Supabase.instance.client
            .from('customers')
            .update(data)
            .eq('id', widget.customerData!['id']);
      } else {
        await Supabase.instance.client.from('customers').insert(data);
      }

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(
              widget.customerData == null
                  ? 'Record saved successfully!'
                  : 'Record updated successfully!',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );

        if (widget.isDialog) {
          Navigator.of(context).pop();
        } else {
          _fetchCustomers();
          // Clear form if not in dialog
          _customerNameController.clear();
          // ... clear other controllers if needed
        }
      }
    } catch (e) {
      debugPrint('Error saving customer: $e');
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
}
