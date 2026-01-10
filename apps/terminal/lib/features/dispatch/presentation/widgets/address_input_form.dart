import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/load.dart';

class AddressInputForm extends StatefulWidget {
  final String title;
  final LoadLocation location;
  final ValueChanged<LoadLocation> onChanged;
  final List<Map<String, dynamic>>? suggestions;
  final bool isPickup;

  const AddressInputForm({
    super.key,
    required this.title,
    required this.location,
    required this.onChanged,
    this.suggestions,
    this.isPickup = true,
  });

  @override
  State<AddressInputForm> createState() => _AddressInputFormState();
}

class _AddressInputFormState extends State<AddressInputForm> {
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _contactNameController;
  late TextEditingController _phoneController;
  late TextEditingController _faxController;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController(
      text: widget.location.companyName,
    );
    _addressController = TextEditingController(text: widget.location.address);
    _cityController = TextEditingController(text: widget.location.city);
    _stateController = TextEditingController(text: widget.location.state);
    _zipController = TextEditingController(text: widget.location.zipCode);
    _contactNameController = TextEditingController(
      text: widget.location.contactName,
    );
    _phoneController = TextEditingController(
      text: widget.location.contactPhone,
    );
    _faxController = TextEditingController(text: widget.location.contactFax);
  }

  @override
  void didUpdateWidget(AddressInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.companyName != widget.location.companyName &&
        _companyController.text != widget.location.companyName) {
      _companyController.text = widget.location.companyName;
    }
    if (oldWidget.location.address != widget.location.address &&
        _addressController.text != widget.location.address) {
      _addressController.text = widget.location.address;
    }
    if (oldWidget.location.city != widget.location.city &&
        _cityController.text != widget.location.city) {
      _cityController.text = widget.location.city;
    }
    if (oldWidget.location.state != widget.location.state &&
        _stateController.text != widget.location.state) {
      _stateController.text = widget.location.state;
    }
    if (oldWidget.location.zipCode != widget.location.zipCode &&
        _zipController.text != widget.location.zipCode) {
      _zipController.text = widget.location.zipCode;
    }
    if (oldWidget.location.contactName != widget.location.contactName &&
        _contactNameController.text != widget.location.contactName) {
      _contactNameController.text = widget.location.contactName;
    }
    if (oldWidget.location.contactPhone != widget.location.contactPhone &&
        _phoneController.text != widget.location.contactPhone) {
      _phoneController.text = widget.location.contactPhone;
    }
    if (oldWidget.location.contactFax != widget.location.contactFax &&
        _faxController.text != widget.location.contactFax) {
      _faxController.text = widget.location.contactFax;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _faxController.dispose();
    super.dispose();
  }

  String get _nameKey => widget.isPickup ? 'shipper_name' : 'receiver_name';

  List<AutoSuggestBoxItem<Map<String, dynamic>>> _getSuggestions() {
    if (widget.suggestions == null || widget.suggestions!.isEmpty) {
      return [];
    }

    final query = _companyController.text.toLowerCase();
    if (query.isEmpty) return [];

    final filtered = widget.suggestions!
        .where((item) {
          final name = (item[_nameKey] ?? '').toString().toLowerCase();
          return name.contains(query);
        })
        .take(10)
        .map<AutoSuggestBoxItem<Map<String, dynamic>>>((item) {
          final name = item[_nameKey] ?? '';
          final city = item['city'] ?? '';
          final state = item['state_province'] ?? '';
          final locationText = (city.isNotEmpty || state.isNotEmpty)
              ? ' · $city, $state'
              : '';
          return AutoSuggestBoxItem<Map<String, dynamic>>(
            value: item,
            label: name,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (locationText.isNotEmpty)
                    TextSpan(
                      text: locationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        })
        .toList();

    return filtered;
  }

  void _onSuggestionSelected(Map<String, dynamic> data) {
    final newLocation = LoadLocation(
      id: data['id'],
      companyName: data[_nameKey] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state_province'] ?? '',
      zipCode: data['postal_code'] ?? '',
      contactName: data['contact_person'] ?? '',
      contactPhone: data['phone'] ?? '',
      contactFax: data['fax'] ?? '',
      date: widget.location.date,
    );

    // Update local controllers to match selected suggestion
    _companyController.text = newLocation.companyName;
    _addressController.text = newLocation.address;
    _cityController.text = newLocation.city;
    _stateController.text = newLocation.state;
    _zipController.text = newLocation.zipCode;
    _contactNameController.text = newLocation.contactName;
    _phoneController.text = newLocation.contactPhone;
    _faxController.text = newLocation.contactFax;

    widget.onChanged(newLocation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : theme.cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark
              ? const Color(0xFF333333)
              : theme.resources.dividerStrokeColorDefault,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Text(
              widget.title,
              style: FluentTheme.of(
                context,
              ).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],

          InfoLabel(
            label: 'Date & Time (${widget.location.date.timeZoneName})',
            child: Row(
              children: [
                Expanded(
                  child: DatePicker(
                    selected: widget.location.date,
                    onChanged: (v) =>
                        widget.onChanged(widget.location.copyWith(date: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TimePicker(
                    selected: widget.location.date,
                    hourFormat: HourFormat.HH,
                    onChanged: (v) =>
                        widget.onChanged(widget.location.copyWith(date: v)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          InfoLabel(
            label: 'Company Name',
            child: widget.suggestions != null && widget.suggestions!.isNotEmpty
                ? AutoSuggestBox<Map<String, dynamic>>(
                    controller: _companyController,
                    placeholder: 'Business/Facility Name',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: _getSuggestions(),
                    onSelected: (item) {
                      if (item.value != null) {
                        _onSuggestionSelected(item.value!);
                      }
                    },
                    onChanged: (text, reason) {
                      if (reason == TextChangedReason.userInput) {
                        widget.onChanged(
                          widget.location.copyWith(companyName: text, id: null),
                        );
                        setState(() {});
                      }
                    },
                  )
                : TextBox(
                    placeholder: 'Business/Facility Name',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _companyController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(companyName: v, id: null),
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          InfoLabel(
            label: 'Address',
            child: TextBox(
              placeholder: 'Street Address',
              decoration: WidgetStateProperty.all(
                BoxDecoration(borderRadius: BorderRadius.circular(4)),
              ),
              controller: _addressController,
              onChanged: (v) => widget.onChanged(
                widget.location.copyWith(address: v, id: null),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Province / State',
                  child: TextBox(
                    placeholder: 'ON',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _stateController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(state: v, id: null),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: InfoLabel(
                  label: 'City',
                  child: TextBox(
                    placeholder: 'Toronto',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _cityController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(city: v, id: null),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Postal / Zip Code',
                  child: TextBox(
                    placeholder: 'M5V 2H1',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _zipController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(zipCode: v, id: null),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          InfoLabel(
            label: 'Contact',
            child: TextBox(
              placeholder: 'Contact Name',
              decoration: WidgetStateProperty.all(
                BoxDecoration(borderRadius: BorderRadius.circular(4)),
              ),
              controller: _contactNameController,
              onChanged: (v) => widget.onChanged(
                widget.location.copyWith(contactName: v, id: null),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Phone',
                  child: TextBox(
                    placeholder: '(555) 123-4567',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _phoneController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(contactPhone: v, id: null),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoLabel(
                  label: 'Fax',
                  child: TextBox(
                    placeholder: 'Optional',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    controller: _faxController,
                    onChanged: (v) => widget.onChanged(
                      widget.location.copyWith(contactFax: v, id: null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
