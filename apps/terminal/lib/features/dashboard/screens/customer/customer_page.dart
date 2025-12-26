import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/trip_entry_scaffold.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  // Form Controllers - Core fields
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Order fields
  final _orderController = TextEditingController();
  final _rateController = TextEditingController();
  String _currency = 'CDN';
  String? _selectedEquipment = 'Dry Van';
  String? _selectedSalesperson;
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
          _selectedSalesperson = name;
          _selectedDispatcher = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      if (mounted && _staffList.isEmpty) {
        setState(() {
          _staffList = ['Maninder Singh'];
          _selectedSalesperson = 'Maninder Singh';
          _selectedDispatcher = 'Maninder Singh';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return TripEntryScaffold(
      title: 'Customer Details',
      actions: [
        Button(child: const Text('Save Record'), onPressed: _saveRecord),
        const SizedBox(width: 8),
        FilledButton(child: const Text('Create Invoice'), onPressed: () {}),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Customer Info
                  _buildSectionHeader('Customer Information'),
                  const SizedBox(height: 16),
                  _buildInlineField(
                    'Customer Name',
                    _customerNameController,
                    flex: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInlineField('Phone', _phoneController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildInlineField('Email', _emailController),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),

                  // Section: Address
                  _buildSectionHeader('Address'),
                  const SizedBox(height: 16),
                  _buildInlineField('Street Address', _addressController),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildInlineField('City', _cityController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInlineField('State', _stateController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInlineField('Zip', _zipCodeController),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),

                  // Section: Order Details
                  _buildSectionHeader('Order Details'),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInlineField('Order #', _orderController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInlineField('Rate', _rateController),
                      ),
                      const SizedBox(width: 16),
                      // Currency toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFFF5F5F5)
                              : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCurrencyButton('USD', isLight),
                            const SizedBox(width: 4),
                            _buildCurrencyButton('CDN', isLight),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          'Equipment',
                          _selectedEquipment,
                          ['Dry Van', 'Reefer', 'Flatbed', 'Step Deck'],
                          (v) => setState(() => _selectedEquipment = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          'Salesperson',
                          _selectedSalesperson,
                          _staffList,
                          (v) => setState(() => _selectedSalesperson = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          'Dispatcher',
                          _selectedDispatcher,
                          _staffList,
                          (v) => setState(() => _selectedDispatcher = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),

                  // Section: Shipment Flags
                  _buildSectionHeader('Shipment Options'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildCompactToggle(
                        'Round Trip',
                        _roundTrip,
                        (v) => setState(() => _roundTrip = v),
                      ),
                      _buildCompactToggle(
                        'Other Carriers',
                        _bookedForOtherCarriers,
                        (v) => setState(() => _bookedForOtherCarriers = v),
                      ),
                      _buildCompactToggle(
                        'CSA/FAST',
                        _csaFastLoad,
                        (v) => setState(() => _csaFastLoad = v),
                      ),
                      _buildCompactToggle(
                        'Bonded',
                        _bondedShipment,
                        (v) => setState(() => _bondedShipment = v),
                      ),
                      _buildCompactToggle(
                        'Hazmat',
                        _dangerousHazmat,
                        (v) => setState(() => _dangerousHazmat = v),
                      ),
                      _buildCompactToggle(
                        'High Priority',
                        _highPriorityLoad,
                        (v) => setState(() => _highPriorityLoad = v),
                      ),
                      _buildCompactToggle(
                        'Team Load',
                        _teamLoad,
                        (v) => setState(() => _teamLoad = v),
                      ),
                      _buildCompactToggle(
                        'Tarp Required',
                        _tarpRequired,
                        (v) => setState(() => _tarpRequired = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),

                  // Section: Notes
                  _buildSectionHeader('Notes'),
                  const SizedBox(height: 16),
                  TextFormBox(
                    controller: _notesController,
                    placeholder: 'Add order notes, special instructions...',
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
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
    int flex = 1,
    String? placeholder,
  }) {
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLight ? const Color(0xFFDDDDDD) : const Color(0xFF444444),
            width: 1,
          ),
        ),
      ),
      child: TextFormBox(
        controller: controller,
        placeholder: placeholder ?? label,
        style: const TextStyle(fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: WidgetStateProperty.all(const BoxDecoration()),
      ),
    );
  }

  Widget _buildCurrencyButton(String currency, bool isLight) {
    final isSelected = _currency == currency;
    return GestureDetector(
      onTap: () => setState(() => _currency = currency),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? FluentTheme.of(context).accentColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          currency,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isLight ? Colors.grey[100] : Colors.grey[80]),
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
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLight ? const Color(0xFFDDDDDD) : const Color(0xFF444444),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ComboBox<String>(
        value: value,
        placeholder: Text(label, style: const TextStyle(fontSize: 15)),
        items: items
            .map((e) => ComboBoxItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }

  Widget _buildCompactToggle(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? FluentTheme.of(context).accentColor.withValues(alpha: 0.15)
              : (isLight ? const Color(0xFFF5F5F5) : const Color(0xFF1E1E1E)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value
                ? FluentTheme.of(context).accentColor
                : (isLight ? const Color(0xFFE0E0E0) : const Color(0xFF333333)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? FluentIcons.check_mark : FluentIcons.circle_ring,
              size: 14,
              color: value
                  ? FluentTheme.of(context).accentColor
                  : Colors.grey[100],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                color: value ? FluentTheme.of(context).accentColor : null,
              ),
            ),
          ],
        ),
      ),
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
  }
}
