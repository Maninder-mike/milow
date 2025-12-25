import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/load.dart';

class AddressInputForm extends StatelessWidget {
  final String title;
  final LoadLocation location;
  final ValueChanged<LoadLocation> onChanged;

  const AddressInputForm({
    super.key,
    required this.title,
    required this.location,
    required this.onChanged,
  });

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
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: FluentTheme.of(
                context,
              ).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],

          // Date & Time (Kept from previous design, important for dispatch)
          InfoLabel(
            label: 'Date & Time (${location.date.timeZoneName})',
            child: Row(
              children: [
                Expanded(
                  child: DatePicker(
                    selected: location.date,
                    onChanged: (v) => onChanged(location.copyWith(date: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TimePicker(
                    selected: location.date,
                    hourFormat: HourFormat.HH,
                    onChanged: (v) => onChanged(location.copyWith(date: v)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Company Name
          InfoLabel(
            label: 'Company Name',
            child: TextBox(
              placeholder: 'Business/Facility Name',
              controller: TextEditingController(text: location.companyName)
                ..selection = TextSelection.collapsed(
                  offset: location.companyName.length,
                ),
              onChanged: (v) => onChanged(location.copyWith(companyName: v)),
            ),
          ),
          const SizedBox(height: 12),

          // Address
          InfoLabel(
            label: 'Address',
            child: TextBox(
              placeholder: 'Street Address',
              controller: TextEditingController(text: location.address)
                ..selection = TextSelection.collapsed(
                  offset: location.address.length,
                ),
              onChanged: (v) => onChanged(location.copyWith(address: v)),
            ),
          ),
          const SizedBox(height: 12),

          // State, City, Zip
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Province / State',
                  child: TextBox(
                    placeholder: 'ON',
                    controller: TextEditingController(text: location.state)
                      ..selection = TextSelection.collapsed(
                        offset: location.state.length,
                      ),
                    onChanged: (v) => onChanged(location.copyWith(state: v)),
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
                    controller: TextEditingController(text: location.city)
                      ..selection = TextSelection.collapsed(
                        offset: location.city.length,
                      ),
                    onChanged: (v) => onChanged(location.copyWith(city: v)),
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
                    controller: TextEditingController(text: location.zipCode)
                      ..selection = TextSelection.collapsed(
                        offset: location.zipCode.length,
                      ),
                    onChanged: (v) => onChanged(location.copyWith(zipCode: v)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Contact
          InfoLabel(
            label: 'Contact',
            child: TextBox(
              placeholder: 'Contact Name',
              controller: TextEditingController(text: location.contactName)
                ..selection = TextSelection.collapsed(
                  offset: location.contactName.length,
                ),
              onChanged: (v) => onChanged(location.copyWith(contactName: v)),
            ),
          ),
          const SizedBox(height: 12),

          // Phone & Fax
          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Phone',
                  child: TextBox(
                    placeholder: '(555) 123-4567',
                    controller:
                        TextEditingController(text: location.contactPhone)
                          ..selection = TextSelection.collapsed(
                            offset: location.contactPhone.length,
                          ),
                    onChanged: (v) =>
                        onChanged(location.copyWith(contactPhone: v)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoLabel(
                  label: 'Fax',
                  child: TextBox(
                    placeholder: 'Optional',
                    controller: TextEditingController(text: location.contactFax)
                      ..selection = TextSelection.collapsed(
                        offset: location.contactFax.length,
                      ),
                    onChanged: (v) =>
                        onChanged(location.copyWith(contactFax: v)),
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
