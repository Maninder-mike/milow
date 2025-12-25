import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/broker.dart';

class BrokerEntryDialog extends StatefulWidget {
  final Future<void> Function(Broker broker) onSave;
  final Broker? initialBroker;

  const BrokerEntryDialog({
    super.key,
    required this.onSave,
    this.initialBroker,
  });

  @override
  State<BrokerEntryDialog> createState() => _BrokerEntryDialogState();
}

class _BrokerEntryDialogState extends State<BrokerEntryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _mcNumberController;
  late TextEditingController _dotNumberController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipCodeController;
  late TextEditingController _countryController;
  late TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final broker = widget.initialBroker ?? Broker.empty();
    _nameController = TextEditingController(text: broker.name);
    _mcNumberController = TextEditingController(text: broker.mcNumber);
    _dotNumberController = TextEditingController(text: broker.dotNumber);
    _phoneNumberController = TextEditingController(text: broker.phoneNumber);
    _emailController = TextEditingController(text: broker.email);
    _addressController = TextEditingController(text: broker.address);
    _cityController = TextEditingController(text: broker.city);
    _stateController = TextEditingController(text: broker.state);
    _zipCodeController = TextEditingController(text: broker.zipCode);
    _countryController = TextEditingController(text: broker.country);
    _notesController = TextEditingController(text: broker.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mcNumberController.dispose();
    _dotNumberController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(widget.initialBroker == null ? 'New Broker' : 'Edit Broker'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(label: 'Identity', child: Divider()),
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Broker Name',
              child: TextBox(
                placeholder: 'Company Name',
                controller: _nameController,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'MC Number',
                    child: TextBox(
                      placeholder: 'MC#',
                      controller: _mcNumberController,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'DOT Number',
                    child: TextBox(
                      placeholder: 'DOT#',
                      controller: _dotNumberController,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InfoLabel(label: 'Contact Info', child: Divider()),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Phone',
                    child: TextBox(
                      placeholder: '(555) 555-5555',
                      controller: _phoneNumberController,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Email',
                    child: TextBox(
                      placeholder: 'dispatch@broker.com',
                      controller: _emailController,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Address',
              child: TextBox(
                placeholder: 'Street Address',
                controller: _addressController,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InfoLabel(
                    label: 'City',
                    child: TextBox(
                      placeholder: 'City',
                      controller: _cityController,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: InfoLabel(
                    label: 'State',
                    child: TextBox(
                      placeholder: 'ST',
                      controller: _stateController,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'Zip',
                    child: TextBox(
                      placeholder: '00000',
                      controller: _zipCodeController,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Country',
              child: TextBox(
                placeholder: 'Country',
                controller: _countryController,
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                placeholder: 'Additional notes...',
                controller: _notesController,
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: ProgressRing())
              : const Text('Save Broker'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) {
      displayInfoBar(
        alignment: Alignment.bottomRight,
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Invalid Input'),
            content: const Text('Broker Name is required.'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    setState(() => _isSaving = true);

    final broker = Broker(
      id: widget.initialBroker?.id ?? '',
      name: _nameController.text,
      mcNumber: _mcNumberController.text,
      dotNumber: _dotNumberController.text,
      phoneNumber: _phoneNumberController.text,
      email: _emailController.text,
      address: _addressController.text,
      city: _cityController.text,
      state: _stateController.text,
      zipCode: _zipCodeController.text,
      country: _countryController.text,
      notes: _notesController.text,
    );

    await widget.onSave(broker);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }
}
