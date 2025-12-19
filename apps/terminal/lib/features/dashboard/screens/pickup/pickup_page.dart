import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/trip_entry_scaffold.dart';

class PickUpPage extends StatefulWidget {
  const PickUpPage({super.key});

  @override
  State<PickUpPage> createState() => _PickUpPageState();
}

class _PickUpPageState extends State<PickUpPage> {
  // Address & Contact Controllers
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();

  // Load Details Controllers
  final _goodsController = TextEditingController();
  final _notesForController = TextEditingController();
  final _masterNotesController = TextEditingController();
  final _appointmentStartController = TextEditingController();
  final _appointmentEndController = TextEditingController();
  final _pickupNotesController = TextEditingController();

  // Search Controllers
  final _storeSearchController = TextEditingController();
  final _addressSearchController = TextEditingController();

  // Dummy Data for Table
  final List<Map<String, String>> _shippers = [];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return TripEntryScaffold(
      title: 'Pick Up Information',
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
                          Expanded(
                            flex: 5,
                            child: _buildAddressSection(context, isLight),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: _buildLoadDetailsSection(context, isLight),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildAddressSection(context, isLight),
                          const SizedBox(height: 24),
                          _buildLoadDetailsSection(context, isLight),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _buildShippersSection(context, isLight),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context, bool isLight) {
    return Column(
      children: [
        _buildCard(
          context,
          isLight: isLight,
          title: 'Address & Contact',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Address'),
              TextFormBox(controller: _addressController),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildLabeledInput('Zip Code', _zipCodeController),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildLabeledInput('Contact', _contactController),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildLabeledInput('Phone', _phoneController),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildLabeledInput('Fax', _faxController)),
                  const SizedBox(width: 16),
                  FilledButton(
                    child: const Text('Save Shipper'),
                    onPressed: () {},
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
          title: 'Search Options',
          child: Row(
            children: [
              Expanded(
                child: _buildLabeledInput('Store #', _storeSearchController),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildLabeledInput(
                  'Search Address',
                  _addressSearchController,
                  placeholder: 'Type to search address...',
                  suffix: const Icon(FluentIcons.search),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadDetailsSection(BuildContext context, bool isLight) {
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Load Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabeledInput('Goods', _goodsController),
          const SizedBox(height: 8),
          _buildLabeledInput('Notes For This Load', _notesForController),
          const SizedBox(height: 8),
          _buildLabeledInput('Master Notes', _masterNotesController),
          const SizedBox(height: 16),
          const Text(
            'Appointment Time',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormBox(
                  controller: _appointmentStartController,
                  placeholder: 'Start',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormBox(
                  controller: _appointmentEndController,
                  placeholder: 'End',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabeledInput('Notes', _pickupNotesController, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildShippersSection(BuildContext context, bool isLight) {
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Shippers List',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isLight ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: isLight
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
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
                    flex: 3,
                    child: Text(
                      'Shipper',
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
                    flex: 2,
                    child: Text(
                      'Appt Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Pick Up',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Contact',
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
                ],
              ),
            ),
            // Rows
            ..._shippers.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isLight
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text(item['seq']!)),
                    Expanded(flex: 3, child: Text(item['shipper']!)),
                    Expanded(flex: 2, child: Text(item['date']!)),
                    Expanded(flex: 2, child: Text(item['apptTime']!)),
                    Expanded(flex: 1, child: Text(item['pickUp']!)),
                    Expanded(flex: 2, child: Text(item['contact']!)),
                    Expanded(flex: 4, child: Text(item['address']!)),
                  ],
                ),
              );
            }),
            // Empty State
            if (_shippers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "No records found",
                    style: TextStyle(
                      color: isLight ? Colors.grey[100] : Colors.grey[80],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
                  color: Colors.black.withValues(alpha: 0.05),
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
