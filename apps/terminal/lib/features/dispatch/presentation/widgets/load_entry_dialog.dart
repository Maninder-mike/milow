import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'address_input_form.dart';
import '../../domain/models/load.dart';
import '../../domain/models/broker.dart';

class LoadEntryDialog extends StatefulWidget {
  final Future<void> Function(Load load) onSave;
  final List<Broker> brokers;
  final Future<Broker?> Function() onAddBroker;

  const LoadEntryDialog({
    super.key,
    required this.onSave,
    required this.brokers,
    required this.onAddBroker,
  });

  @override
  State<LoadEntryDialog> createState() => _LoadEntryDialogState();
}

class _LoadEntryDialogState extends State<LoadEntryDialog> {
  // Fluent UI manual form state

  Broker? _selectedBroker;
  late List<Broker> _localBrokers;

  // String _brokerName = ''; // Removed in favor of _selectedBroker
  String _loadReference = '';
  double _rate = 0.0;
  String _currency = 'CAD';
  String _goods = '';
  LoadLocation _pickup = LoadLocation.empty();
  LoadLocation _delivery = LoadLocation.empty();
  // String _pickupLocation = '';
  // DateTime _pickupDate = DateTime.now();
  // String _deliveryLocation = '';
  // DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));
  String _loadNotes = '';
  String _companyNotes = '';

  bool _isSaving = false;
  Offset _offset = Offset.zero; // For draggable logic
  final TextEditingController _brokerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localBrokers = List.from(widget.brokers);
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 900),
        title: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _offset += details.delta;
            });
          },
          child: Container(
            color: Colors.transparent, // Hit test behavior
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('New Load Entry (Drag me)'),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoLabel(label: 'Broker Details', child: Divider()),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Broker Name',
                      child: AutoSuggestBox<Broker>(
                        controller: _brokerController,
                        placeholder: 'Search or Add Broker',
                        items: _getBrokerSuggestions(),
                        onSelected: (item) {
                          if (item.value == null) {
                            // "Add New" selected
                            _onBrokerChanged(null);
                          } else {
                            // Existing broker selected
                            setState(() {
                              _selectedBroker = item.value;
                              // Ensure text matches selected name exactly (optional, usually AutoSuggestBox does this)
                            });
                          }
                        },
                        onChanged: (text, reason) {
                          if (reason == TextChangedReason.userInput) {
                            // Clear selection if user types something new
                            if (_selectedBroker != null &&
                                text != _selectedBroker!.name) {
                              setState(() {
                                _selectedBroker = null;
                              });
                            }
                            // Force rebuild to update suggestions based on text
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: 'Load Ref #',
                      child: TextBox(
                        placeholder: 'Reference Number',
                        onChanged: (value) => _loadReference = value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Rate',
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: NumberBox<double>(
                              value: _rate,
                              onChanged: (value) =>
                                  setState(() => _rate = value ?? 0.0),
                              mode: SpinButtonPlacementMode.none,
                              placeholder: 'Amount',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: ComboBox<String>(
                              value: _currency,
                              items: const [
                                ComboBoxItem(value: 'CAD', child: Text('CAD')),
                                ComboBoxItem(value: 'USD', child: Text('USD')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _currency = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: 'Goods / Commodity',
                      child: TextBox(
                        placeholder: 'e.g. General Freight, Produce',
                        onChanged: (value) => _goods = value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InfoLabel(label: 'Trip Details', child: Divider()),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PICKUP SECTION (LEFT) ---
                  Expanded(
                    child: AddressInputForm(
                      title: '',
                      location: _pickup,
                      onChanged: (v) => setState(() => _pickup = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // --- DELIVERY SECTION (RIGHT) ---
                  Expanded(
                    child: AddressInputForm(
                      title: '',
                      location: _delivery,
                      onChanged: (v) => setState(() => _delivery = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'Load Notes',
                      child: TextBox(
                        placeholder: 'Notes specific to this load',
                        maxLines: 3,
                        onChanged: (value) => _loadNotes = value,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: 'Company Notes',
                      child: TextBox(
                        placeholder: 'Notes about the company/broker',
                        maxLines: 3,
                        onChanged: (value) => _companyNotes = value,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: ProgressRing(),
                      )
                    : const Text('Save Load'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Basic validation
    if (_selectedBroker == null || _loadReference.isEmpty || _rate <= 0) {
      // Show error info bar or similar
      displayInfoBar(
        alignment: Alignment.bottomRight,
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Missing Info'),
            content: const Text('Please select a Broker, Ref #, and Rate > 0'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    setState(() => _isSaving = true);

    final newLoad = Load(
      id: '', // Generated by backend usually
      loadReference: _loadReference,
      brokerName: _selectedBroker!.name,
      rate: _rate,
      currency: _currency,
      goods: _goods,
      pickup: _pickup,
      delivery: _delivery,
      status: 'Pending',
      loadNotes: _loadNotes,
      companyNotes: _companyNotes,
      tripNumber: '',
    );

    await widget.onSave(newLoad);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  List<AutoSuggestBoxItem<Broker>> _getBrokerSuggestions() {
    final query = _brokerController.text.toLowerCase();

    // Filter existing brokers
    final filtered = _localBrokers
        .where((b) {
          return b.name.toLowerCase().contains(query);
        })
        .map<AutoSuggestBoxItem<Broker>>((b) {
          return AutoSuggestBoxItem<Broker>(
            value: b,
            label: b.name,
            child: Text(b.name, overflow: TextOverflow.ellipsis),
          );
        })
        .toList();

    // Always add "Add New" option if query is not empty and doesn't exactly match an existing one
    // Or just always add it at the bottom for convenience

    // Customize the "Add New" text based on what they typed
    final addLabel = query.isEmpty ? '+ Add New Broker' : '+ Add "$query"';

    filtered.add(
      AutoSuggestBoxItem<Broker>(
        value: null, // Signals "Add New"
        label: addLabel,
        child: Row(
          children: [
            const Icon(FluentIcons.add_24_regular, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                addLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    return filtered;
  }

  void _onBrokerChanged(Broker? value) async {
    if (value == null) {
      // Add New Broker selected
      final newBroker = await widget.onAddBroker();
      if (newBroker != null) {
        setState(() {
          _localBrokers.add(newBroker);
          _selectedBroker = newBroker;
          _brokerController.text = newBroker.name; // Update text box
        });
      } else {
        // User cancelled adding broker, maybe revert text or keep it?
        // If they cancelled, we probably shouldn't set a selection.
        // We'll leave the text as is so they can try again or select another.
      }
    } else {
      // Should not be called directly with non-null from AutoSuggestBox logic above,
      // but good for safety or if we reuse this method.
      setState(() {
        _selectedBroker = value;
        _brokerController.text = value.name;
      });
    }
  }
}
