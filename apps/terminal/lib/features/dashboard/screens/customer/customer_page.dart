import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/trip_entry_scaffold.dart';
import 'package:terminal/core/constants/location_data.dart';

class CustomerPage extends StatefulWidget {
  final bool isDialog;
  const CustomerPage({super.key, this.isDialog = false});

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

  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
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
                      'Add New Customer',
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
                onPressed: _saveRecord,
                child: const Text('Save Record'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildCustomerList(isLight)],
        ),
      ),
    );
  }

  void _openAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      // Change: passing the widget directly, avoiding double-wrapping in ContentDialog
      // effectively delegating ContentDialog creation to the widget itself now.
      builder: (context) => const CustomerPage(isDialog: true),
    );
  }

  Widget _buildCustomerList(bool isLight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(FluentIcons.people, size: 48, color: Colors.grey[100]),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the "Add Customer" button to create your first record.',
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Contact Details
        _buildSectionHeader('Contact details'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildInlineField(
                'Customer Name',
                _customerNameController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: _buildInlineField('Phone', _phoneController)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildInlineField('Email', _emailController)),
            const SizedBox(width: 24),
            Expanded(child: _buildInlineField('Fax', _faxController)),
          ],
        ),

        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 32),

        // Section: Address
        _buildSectionHeader('Address details'),
        const SizedBox(height: 20),
        _buildInlineField('Street Address', _addressController),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildInlineField('City', _cityController),
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
              child: _buildInlineField('Zip Code', _zipCodeController),
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
        _buildDivider(),
        const SizedBox(height: 32),

        // Section: Order Details
        _buildSectionHeader('Order & Logistics'),
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
              child: _buildInlineField('Order Number', _orderController),
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
              child: _buildInlineField(
                'Reference Numbers',
                _referenceController,
                placeholder: 'PO, BOL, Pickup #',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildInlineField('Rate', _rateController)),
            const SizedBox(width: 24),
            _buildCurrencyToggle(isLight),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildInlineField(
                'Payment Terms',
                _paymentTermsController,
                placeholder: 'e.g. Net 30',
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 32),

        // Section: Shipment Flags
        _buildSectionHeader('Additional flags'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildFlagChip(
              'Round Trip',
              _roundTrip,
              FluentIcons.repeat_all,
              (v) => setState(() => _roundTrip = v),
            ),
            _buildFlagChip(
              'Other Carriers',
              _bookedForOtherCarriers,
              FluentIcons.account_management,
              (v) => setState(() => _bookedForOtherCarriers = v),
            ),
            _buildFlagChip(
              'CSA/FAST',
              _csaFastLoad,
              FluentIcons.verified_brand,
              (v) => setState(() => _csaFastLoad = v),
            ),
            _buildFlagChip(
              'Bonded Load',
              _bondedShipment,
              FluentIcons.lock,
              (v) => setState(() => _bondedShipment = v),
            ),
            _buildFlagChip(
              'Hazmat',
              _dangerousHazmat,
              FluentIcons.warning,
              (v) => setState(() => _dangerousHazmat = v),
            ),
            _buildFlagChip(
              'High Priority',
              _highPriorityLoad,
              FluentIcons.unstack_selected,
              (v) => setState(() => _highPriorityLoad = v),
            ),
            _buildFlagChip(
              'Team Load',
              _teamLoad,
              FluentIcons.people,
              (v) => setState(() => _teamLoad = v),
            ),
            _buildFlagChip(
              'Tarp Required',
              _tarpRequired,
              FluentIcons.all_apps,
              (v) => setState(() => _tarpRequired = v),
            ),
            _buildFlagChip(
              'Appointment Req',
              _appointmentRequired,
              FluentIcons.calendar,
              (v) => setState(() => _appointmentRequired = v),
            ),
            _buildFlagChip(
              'Liftgate Needed',
              _liftgateNeeded,
              FluentIcons.up,
              (v) => setState(() => _liftgateNeeded = v),
            ),
            _buildFlagChip(
              'Residential',
              _residentialDelivery,
              FluentIcons.home,
              (v) => setState(() => _residentialDelivery = v),
            ),
            _buildFlagChip(
              'Driver Assist',
              _driverAssist,
              FluentIcons.customer_assets,
              (v) => setState(() => _driverAssist = v),
            ),
            _buildFlagChip(
              'Drop Trailer',
              _dropTrailer,
              FluentIcons.down,
              (v) => setState(() => _dropTrailer = v),
            ),
            _buildFlagChip(
              'Port/Rail',
              _portRail,
              FluentIcons.product,
              (v) => setState(() => _portRail = v),
            ),
            _buildFlagChip(
              'Non-Stackable',
              _nonStackable,
              FluentIcons.stop,
              (v) => setState(() => _nonStackable = v),
            ),
            _buildFlagChip(
              'Fragile',
              _fragile,
              FluentIcons.diamond,
              (v) => setState(() => _fragile = v),
            ),
          ],
        ),

        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 32),

        // Section: Notes
        _buildSectionHeader('Special instructions & Notes'),
        const SizedBox(height: 16),
        TextFormBox(
          controller: _notesController,
          placeholder:
              'Add any specific instructions for the driver or office...',
          maxLines: 4,
          style: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: FluentTheme.of(context).accentColor,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
    );
  }

  Widget _buildInlineField(
    String label,
    TextEditingController controller, {
    String? placeholder,
  }) {
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
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
              color: isLight ? Colors.grey[140] : Colors.grey[80],
            ),
          ),
        ),
        TextFormBox(
          controller: controller,
          placeholder: placeholder,
          style: const TextStyle(fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
      ],
    );
  }

  Widget _buildCurrencyToggle(bool isLight) {
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
              color: isLight ? Colors.grey[140] : Colors.grey[80],
            ),
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF3F3F3) : const Color(0xFF202020),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFE5E5E5)
                  : const Color(0xFF333333),
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

  Widget _buildFlagChip(
    String label,
    bool value,
    IconData icon,
    Function(bool) onChanged,
  ) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: value
              ? theme.accentColor
              : (isLight ? const Color(0xFFF0F0F0) : const Color(0xFF2D2D2D)),
          borderRadius: BorderRadius.circular(100), // Pill shape
          border: Border.all(
            color: value
                ? theme.accentColor
                : (isLight ? const Color(0xFFE5E5E5) : const Color(0xFF3D3D3D)),
            width: 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: value
                  ? Colors.white
                  : (isLight ? Colors.grey[140] : Colors.grey[80]),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value
                    ? Colors.white
                    : (isLight
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyButton(String currency, bool isLight) {
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
                : (isLight ? Colors.grey[120] : Colors.grey[100]),
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
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
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
              color: isLight ? Colors.grey[140] : Colors.grey[80],
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

  void _saveRecord() {
    // TODO: Implement save logic
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Record saved!'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );

    if (widget.isDialog) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }
}
