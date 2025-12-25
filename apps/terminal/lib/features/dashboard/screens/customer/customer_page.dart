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
  // Form Controllers
  // Column 1
  final _customerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _unitController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();
  final _payableEmailController = TextEditingController();
  final _contactController = TextEditingController();
  final _dispatcherEmailController = TextEditingController();
  final _sealNumberController = TextEditingController();
  final _customsBrokerController = TextEditingController();
  final _brokerPhoneController = TextEditingController();
  final _brokerEmailController = TextEditingController();
  final _parsPapsController = TextEditingController();
  bool _blockInvoicePrinting = false;
  final _internalNotesController = TextEditingController();

  // Column 2
  final _orderController = TextEditingController();
  final _rateController = TextEditingController();
  String _currency = 'CDN'; // USD or CDN
  final _notesController = TextEditingController();
  String? _selectedSalesperson = 'Maninder Singh';
  String? _selectedDispatcher = 'Maninder Singh';
  List<String> _staffList = [];
  String? _selectedEquipment = 'Dry Van';

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

      // Response is a Map since we used single()
      final Map<String, dynamic> data = response;
      final String? name = data['full_name'] as String?;

      if (mounted && name != null && name.isNotEmpty) {
        setState(() {
          _staffList = [name]; // Only current user
          _selectedSalesperson = name;
          _selectedDispatcher = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      // Fallback dummy data if fetch fails
      if (mounted && _staffList.isEmpty) {
        setState(() {
          // Fallback to a generic name or keep empty?
          // User said "only his profile details", so maybe just generic or nothing.
          // But existing fallback is fine for dev/error state.
          _staffList = ['Maninder Singh'];
          _selectedSalesperson = 'Maninder Singh';
          _selectedDispatcher = 'Maninder Singh';
        });
      }
    }
  }

  // Flags
  bool _roundTrip = false;
  bool _bookedForOtherCarriers =
      false; // "Booked for other Carriers" (from image)
  bool _sendToFactor = false; // "Send To Factor"
  bool _csaFastLoad = false;
  bool _bondedShipmentUS = false;
  bool _bondedShipmentCA = false;
  bool _dangerousHazmat = false;
  bool _resetCustomsBroker = false;
  bool _highPriorityLoad = false;
  bool _teamLoad = false;
  bool _cityDriverRequired = false;
  bool _tarpRequired = false;

  // Column 3
  DateTime _selectedDate = DateTime.now();
  // Tax Calc
  bool _hstEnabled = false;
  final _hstController = TextEditingController();
  bool _pstEnabled = false;
  final _pstController = TextEditingController();
  final _totalTaxController = TextEditingController();

  // Rate Calc
  final _totalMilesController = TextEditingController();
  final _perMileController = TextEditingController();
  final _totalHoursController = TextEditingController();
  final _perHourController = TextEditingController();
  final _fuelSurchargeController = TextEditingController();

  // Bottom Table
  // (Placeholder for now)

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return TripEntryScaffold(
      title: 'Customer Details',
      actions: [
        Button(child: const Text('Save Record'), onPressed: () {}),
        const SizedBox(width: 8),
        FilledButton(child: const Text('Create Invoice'), onPressed: () {}),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1000;
          final contentWidth = isWide ? constraints.maxWidth : 600.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel (Address & Contact)
                          Expanded(
                            flex: 4,
                            child: _buildAddressSection(context, isLight),
                          ),
                          const SizedBox(width: 24),
                          // Right Panel (Order & Details)
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildOrderSection(context, isLight),
                                const SizedBox(height: 24),
                                _buildDetailsSection(context, isLight),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildAddressSection(context, isLight),
                          const SizedBox(height: 24),
                          _buildOrderSection(context, isLight),
                          const SizedBox(height: 24),
                          _buildDetailsSection(context, isLight),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _buildChargesSection(context, isLight),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Widget child,
    String? title,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 24),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context, bool isLight) {
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Address & Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabeledInput('Customer Name', _customerNameController),
          const SizedBox(height: 16),
          _buildLabel('Address'),
          TextFormBox(controller: _addressController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildLabeledInput('State', _stateController),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildLabeledInput('City', _cityController),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildLabeledInput('Unit', _unitController)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLabeledInput('Zip Code', _zipCodeController),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLabeledInput('Phone', _phoneController)),
              const SizedBox(width: 8),
              Expanded(child: _buildLabeledInput('Fax', _faxController)),
            ],
          ),
          const SizedBox(height: 8),
          _buildLabeledInput('Payable E-mail', _payableEmailController),
          const SizedBox(height: 16),
          _buildLabeledInput('Contact', _contactController),
          const SizedBox(height: 8),
          _buildLabeledInput(
            'Dispatcher\'s E-mail',
            _dispatcherEmailController,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildLabeledInput('Seal Number', _sealNumberController),
          const SizedBox(height: 8),
          _buildLabeledInput('Customs Broker', _customsBrokerController),
          const SizedBox(height: 8),
          _buildLabeledInput('Phone/Fax', _brokerPhoneController),
          const SizedBox(height: 8),
          _buildLabeledInput('Email', _brokerEmailController),
          const SizedBox(height: 8),
          _buildLabeledInput('PARS/PAPS', _parsPapsController),
          const SizedBox(height: 16),
          Checkbox(
            checked: _blockInvoicePrinting,
            onChanged: (v) =>
                setState(() => _blockInvoicePrinting = v ?? false),
            content: const Text('Block Invoice Printing'),
          ),
          const SizedBox(height: 16),
          _buildLabel('Internal Notes'),
          TextFormBox(controller: _internalNotesController, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildOrderSection(BuildContext context, bool isLight) {
    return Column(
      children: [
        _buildCard(
          context,
          isLight: isLight,
          title: 'Order Info',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Order #'),
              TextFormBox(
                controller: _orderController,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: WidgetStateProperty.all(
                  BoxDecoration(
                    color: FluentTheme.of(
                      context,
                    ).accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLabeledInput('Rate', _rateController)),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      RadioButton(
                        checked: _currency == 'USD',
                        onChanged: (v) => setState(() => _currency = 'USD'),
                        content: const Text('USD'),
                      ),
                      const SizedBox(width: 16),
                      RadioButton(
                        checked: _currency == 'CDN',
                        onChanged: (v) => setState(() => _currency = 'CDN'),
                        content: const Text('CDN'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Notes'),
              TextFormBox(controller: _notesController, maxLines: 2),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Salesperson',
                      child: ComboBox<String>(
                        value: _selectedSalesperson,
                        items: _staffList
                            .map((e) => ComboBoxItem(value: e, child: Text(e)))
                            .toList(),
                        placeholder: const Text('Select...'),
                        onChanged: (v) =>
                            setState(() => _selectedSalesperson = v),
                        isExpanded: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InfoLabel(
                      label: 'Dispatcher',
                      child: ComboBox<String>(
                        value: _selectedDispatcher,
                        items: _staffList
                            .map((e) => ComboBoxItem(value: e, child: Text(e)))
                            .toList(),
                        placeholder: const Text('Select...'),
                        onChanged: (v) =>
                            setState(() => _selectedDispatcher = v),
                        isExpanded: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCard(
          context,
          isLight: isLight,
          title: 'Shipment Flags',
          child: _buildMultiSelectFlags(context),
        ),
        const SizedBox(height: 24),
        _buildCard(
          context,
          isLight: isLight,
          child: InfoLabel(
            label: 'Equipment',
            child: ComboBox<String>(
              value: _selectedEquipment,
              items: const [
                ComboBoxItem(value: 'Dry Van', child: Text('Dry Van')),
                ComboBoxItem(value: 'Reefer', child: Text('Reefer')),
                ComboBoxItem(value: 'Flatbed', child: Text('Flatbed')),
              ],
              onChanged: (v) => setState(() => _selectedEquipment = v),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context, bool isLight) {
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DatePicker(
            header: 'Date',
            selected: _selectedDate,
            onChanged: (v) => setState(() => _selectedDate = v),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tax Calculator',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                checked: _hstEnabled,
                onChanged: (v) => setState(() => _hstEnabled = v ?? false),
                content: const Text('HST'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormBox(
                  controller: _hstController,
                  placeholder: '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                checked: _pstEnabled,
                onChanged: (v) => setState(() => _pstEnabled = v ?? false),
                content: const Text('PST'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormBox(
                  controller: _pstController,
                  placeholder: '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Total',
            child: TextFormBox(
              controller: _totalTaxController,
              readOnly: true,
              placeholder: '0.00',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rate Calculation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildLabeledInput('Total Miles', _totalMilesController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLabeledInput('Per Mile', _perMileController),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildLabeledInput('Total Hours', _totalHoursController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLabeledInput('Per Hour', _perHourController),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabeledInput(
            'Fuel Surcharge Per Mile',
            _fuelSurchargeController,
          ),
        ],
      ),
    );
  }

  Widget _buildChargesSection(BuildContext context, bool isLight) {
    // Placeholder table logic remains similar
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Other Charges',
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: isLight
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.8),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Percentage',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Deduct',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'HST',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _flyoutController = FlyoutController();

  Widget _buildMultiSelectFlags(BuildContext context) {
    // Count selected
    final flags = [
      _roundTrip,
      _bookedForOtherCarriers,
      _sendToFactor,
      _csaFastLoad,
      _bondedShipmentUS,
      _bondedShipmentCA,
      _dangerousHazmat,
      _resetCustomsBroker,
      _highPriorityLoad,
      _teamLoad,
      _cityDriverRequired,
      _tarpRequired,
    ];
    final selectedCount = flags.where((e) => e).length;
    final buttonText = selectedCount > 0
        ? '$selectedCount Flags Selected'
        : 'Select Shipment Flags...';

    return FlyoutTarget(
      controller: _flyoutController,
      child: Button(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.flag, size: 16),
            const SizedBox(width: 8),
            Text(buttonText),
            const SizedBox(width: 8),
            const Icon(FluentIcons.chevron_down, size: 12),
          ],
        ),
        onPressed: () {
          _flyoutController.showFlyout(
            autoModeConfiguration: FlyoutAutoConfiguration(
              preferredMode: FlyoutPlacementMode.bottomLeft,
            ),
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            dismissWithEsc: true,
            builder: (context) {
              return MenuFlyout(
                items: [
                  _buildFlagMenuItem(
                    'Round Trip',
                    _roundTrip,
                    (v) => _roundTrip = v,
                  ),
                  _buildFlagMenuItem(
                    'Booked for other Carriers',
                    _bookedForOtherCarriers,
                    (v) => _bookedForOtherCarriers = v,
                  ),
                  _buildFlagMenuItem(
                    'Send To Factor',
                    _sendToFactor,
                    (v) => _sendToFactor = v,
                  ),
                  _buildFlagMenuItem(
                    'CSA/FAST Load',
                    _csaFastLoad,
                    (v) => _csaFastLoad = v,
                  ),
                  _buildFlagMenuItem(
                    'Bonded Shipment(US)',
                    _bondedShipmentUS,
                    (v) => _bondedShipmentUS = v,
                  ),
                  _buildFlagMenuItem(
                    'Bonded Shipment(CA)',
                    _bondedShipmentCA,
                    (v) => _bondedShipmentCA = v,
                  ),
                  _buildFlagMenuItem(
                    'Dangerous / Hazmat Goods',
                    _dangerousHazmat,
                    (v) => _dangerousHazmat = v,
                  ),
                  _buildFlagMenuItem(
                    'Reset Customs Broker',
                    _resetCustomsBroker,
                    (v) => _resetCustomsBroker = v,
                  ),
                  _buildFlagMenuItem(
                    'High Priority Load',
                    _highPriorityLoad,
                    (v) => _highPriorityLoad = v,
                  ),
                  _buildFlagMenuItem(
                    'Team Load',
                    _teamLoad,
                    (v) => _teamLoad = v,
                  ),
                  _buildFlagMenuItem(
                    'City Driver Required',
                    _cityDriverRequired,
                    (v) => _cityDriverRequired = v,
                  ),
                  _buildFlagMenuItem(
                    'Tarp Required',
                    _tarpRequired,
                    (v) => _tarpRequired = v,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  MenuFlyoutItem _buildFlagMenuItem(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return MenuFlyoutItem(
      text: Text(label),
      leading: Checkbox(
        checked: value,
        onChanged: (v) {
          setState(() => onChanged(v ?? false));
          Navigator.of(context).pop();
        },
      ),
      onPressed: () {
        setState(() => onChanged(!value));
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildLabeledInput(
    String label,
    TextEditingController controller, {
    String? placeholder,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return InfoLabel(
      label: label,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      child: TextFormBox(
        controller: controller,
        placeholder: placeholder,
        suffix: suffix,
        maxLines: maxLines,
      ),
    );
  }
}
