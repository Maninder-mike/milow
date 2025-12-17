import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/trip_entry_scaffold.dart';

class DeliverPage extends StatefulWidget {
  const DeliverPage({super.key});

  @override
  State<DeliverPage> createState() => _DeliverPageState();
}

class _DeliverPageState extends State<DeliverPage> {
  // Address & Contact Controllers
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _unitController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _faxController = TextEditingController();

  // Load Details Controllers
  final _notesForController = TextEditingController();
  final _masterNotesController = TextEditingController();
  final _appointmentStartController = TextEditingController();
  final _appointmentEndController = TextEditingController();

  // Search Controllers
  final _storeSearchController = TextEditingController();
  final _addressSearchController = TextEditingController();

  // Dummy Data for Table
  final List<Map<String, String>> _receivers = [];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return TripEntryScaffold(
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
                    _buildReceiversSection(context, isLight),
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
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildLabeledInput('Unit', _unitController),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
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
                    child: const Text('Save Receiver'),
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
          title: 'Further Search Option',
          child: Row(
            children: [
              Expanded(
                child: _buildLabeledInput(
                  'Store #',
                  _storeSearchController,
                  placeholder: 'Like Walmart/Sobeys',
                ),
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
    final theme = FluentTheme.of(context);
    final instructionStyle = TextStyle(
      fontSize: 11,
      color: theme.resources.textFillColorSecondary,
      height: 1.4,
    );

    return _buildCard(
      context,
      isLight: isLight,
      title: 'Load Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabeledInput(
            'Notes For This Load',
            _notesForController,
            maxLines: 3,
          ),
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
          const SizedBox(height: 24),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '1. For Sharp Appt: Enter Time in "Start Box" example 6am as 600, 7.30 pm as 1930',
            style: instructionStyle,
          ),
          Text(
            '2. Between Time: Enter in "Start" "End"',
            style: instructionStyle,
          ),
          Text('3. TBA: Leave "Start" "End" Blank', style: instructionStyle),
          Text(
            '4. Any Time: feed 900 in "Start" 1700 in "End"',
            style: instructionStyle,
          ),
          Text(
            '5. Before Time: Leave "Start" Blank, Enter in "End"',
            style: instructionStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiversSection(BuildContext context, bool isLight) {
    return _buildCard(
      context,
      isLight: isLight,
      title: 'Receivers List',
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
                  : Colors.grey.withOpacity(0.2),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Smo',
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
                      'Delivery Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Appointment Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Reference',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Contact Person',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Skids',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Cases',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Weight',
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
                    child: Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Empty State
            if (_receivers.isEmpty)
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
