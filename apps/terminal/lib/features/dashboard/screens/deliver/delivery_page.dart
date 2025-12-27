import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/trip_entry_scaffold.dart';

class DeliveryPage extends StatefulWidget {
  final bool isDialog;
  const DeliveryPage({super.key, this.isDialog = false});

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

  // Schedule
  DateTime _selectedDate = DateTime.now();
  DateTime _startTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    8,
    0,
  );

  // Schedule & Logistics state
  String _appointmentType = 'Live Unload';
  String _schedulingWindow = 'Strict Appointment';

  bool _driverAssist = false;
  bool _ppeRequired = false;
  bool _overnightParking = false;
  bool _strictLatePolicy = false;
  bool _callBeforeArrival = false;

  final _refNumberController = TextEditingController();

  // Dummy Data for Table
  final List<Map<String, String>> _receivers = [];

  Offset _offset = Offset.zero;

  // Constants for Dropdowns (reused)
  static const _canadianProvinces = {
    'AB': 'Alberta',
    'BC': 'British Columbia',
    'MB': 'Manitoba',
    'NB': 'New Brunswick',
    'NL': 'Newfoundland and Labrador',
    'NS': 'Nova Scotia',
    'NT': 'Northwest Territories',
    'NU': 'Nunavut',
    'ON': 'Ontario',
    'PE': 'Prince Edward Island',
    'QC': 'Quebec',
    'SK': 'Saskatchewan',
    'YT': 'Yukon',
  };

  static const _usStates = {
    'AK': 'Alaska',
    'AL': 'Alabama',
    'AR': 'Arkansas',
    'AZ': 'Arizona',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DC': 'District of Columbia',
    'DE': 'Delaware',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'IA': 'Iowa',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'MA': 'Massachusetts',
    'MD': 'Maryland',
    'ME': 'Maine',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MO': 'Missouri',
    'MS': 'Mississippi',
    'MT': 'Montana',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'NE': 'Nebraska',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NV': 'Nevada',
    'NY': 'New York',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VA': 'Virginia',
    'VT': 'Vermont',
    'WA': 'Washington',
    'WI': 'Wisconsin',
    'WV': 'West Virginia',
    'WY': 'Wyoming',
  };

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
                      'Add New Receiver',
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Receiver'),
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
                      _buildSectionHeader('Receiver Location'),
                      const SizedBox(height: 16),
                      _buildInlineField(
                        'Receiver Company Name',
                        _companyNameController,
                      ),
                      const SizedBox(height: 16),
                      _buildInlineField('Street Address', _addressController),
                      const SizedBox(height: 16),
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
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    bottom: 6,
                                  ),
                                  child: _buildLabel('State/Prov'),
                                ),
                                ComboBox<String>(
                                  value: _state,
                                  placeholder: const Text(
                                    'Select...',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  items: [
                                    // Canada
                                    ..._canadianProvinces.entries.map(
                                      (e) => ComboBoxItem(
                                        value: e.value,
                                        child: Text(
                                          '${e.key} - ${e.value}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    // USA
                                    ..._usStates.entries.map(
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
                            child: _buildInlineField(
                              'Zip Code',
                              _zipCodeController,
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
                              ['Canada', 'USA', 'Mexico'],
                              (v) => setState(
                                () => _countryController.text = v ?? 'Canada',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),

                      // Section: Contact Details
                      _buildSectionHeader('Contact Details'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineField(
                              'Contact Person',
                              _contactController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInlineField('Phone', _phoneController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineField('Email', _emailController),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInlineField('Fax', _faxController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),

                      // Section: Schedule & Reference
                      _buildSectionHeader('Schedule & Reference'),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Delivery Date'),
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
                                _buildLabel('Appointment Time'),
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
                            child: _buildDropdown(
                              'Appointment Type',
                              _appointmentType,
                              ['Live Unload', 'Drop Trailer'],
                              (v) => setState(
                                () => _appointmentType = v ?? 'Live Unload',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown(
                              'Scheduling Window',
                              _schedulingWindow,
                              ['Strict Appointment', 'FCFS', 'Window (2hr)'],
                              (v) => setState(
                                () => _schedulingWindow =
                                    v ?? 'Strict Appointment',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildToggleChip(
                            'PPE Required',
                            FluentIcons.shield,
                            _ppeRequired,
                            (v) => setState(() => _ppeRequired = v),
                          ),
                          _buildToggleChip(
                            'Driver Assist',
                            FluentIcons.people,
                            _driverAssist,
                            (v) => setState(() => _driverAssist = v),
                          ),
                          _buildToggleChip(
                            'Overnight Parking',
                            FluentIcons.parking_location,
                            _overnightParking,
                            (v) => setState(() => _overnightParking = v),
                          ),
                          _buildToggleChip(
                            'Strict "Late" Policy',
                            FluentIcons.timer,
                            _strictLatePolicy,
                            (v) => setState(() => _strictLatePolicy = v),
                          ),
                          _buildToggleChip(
                            'Call 1hr Before',
                            FluentIcons.phone,
                            _callBeforeArrival,
                            (v) => setState(() => _callBeforeArrival = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInlineField(
                        'Reference Numbers',
                        _refNumberController,
                        placeholder: 'DEL #, REF #',
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
      title: 'Delivery Information',
      actions: [
        FilledButton(
          onPressed: () => _openAddReceiverDialog(context),
          child: const Row(
            children: [
              Icon(FluentIcons.add, size: 12),
              SizedBox(width: 8),
              Text('Add Receiver'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildReceiversSection(context, isLight)],
        ),
      ),
    );
  }

  void _openAddReceiverDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DeliveryPage(isDialog: true),
    );
  }

  Widget _buildReceiversSection(BuildContext context, bool isLight) {
    return Expanded(
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
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Seq',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Receiver',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Ref #',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Address',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Cargo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 48), // Actions spacer
              ],
            ),
          ),
          // Rows
          ..._receivers.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isLight
                        ? const Color(0xFFF0F0F0)
                        : const Color(0xFF444444),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text(item['seq']!)),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusBadge(item['status']!),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['receiver']!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['ref'] ?? '--',
                      style: TextStyle(
                        fontSize: 13,
                        color: isLight ? Colors.grey[140] : Colors.grey[80],
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
                          item['date']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          item['apptTime']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight
                                ? Colors.grey[120]
                                : Colors.grey[100],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      item['address']!,
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
                          item['weight'] ?? '--',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${item['pieces'] ?? '0'} pcs',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight
                                ? Colors.grey[120]
                                : Colors.grey[100],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(FluentIcons.more, size: 16),
                        onPressed: null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Empty State
          if (_receivers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      FluentIcons.package,
                      size: 48,
                      color: isLight ? Colors.grey[100] : Colors.grey[60],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No delivery records found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isLight ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Click 'Add Receiver' to schedule a new one.",
                      style: TextStyle(
                        color: isLight ? Colors.grey[100] : Colors.grey[80],
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

  // --- Helper Widgets matching Pickup Page ---

  Widget _buildToggleChip(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    // Get the current accent color from the theme
    final accentColor = FluentTheme.of(context).accentColor;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? accentColor : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value
                ? accentColor
                : Colors.grey[140], // Light grey border for unselected
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: value ? Colors.white : Colors.white.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildLabel(String text) {
    final isLight = FluentTheme.of(context).brightness == Brightness.light;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isLight ? Colors.grey[140] : Colors.grey[80],
      ),
    );
  }

  Widget _buildInlineField(
    String label,
    TextEditingController controller, {
    String? placeholder,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: _buildLabel(label),
        ),
        TextFormBox(
          controller: controller,
          placeholder: placeholder,
          suffix: suffix,
          maxLines: maxLines,
          padding: const EdgeInsets.all(10),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: _buildLabel(label),
        ),
        ComboBox<String>(
          value: value,
          items: items
              .map(
                (e) => ComboBoxItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
          placeholder: const Text('Select', style: TextStyle(fontSize: 14)),
        ),
      ],
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
}
