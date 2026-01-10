import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/load_providers.dart';
import 'address_input_form.dart';
import '../../domain/models/load.dart';
import '../../domain/models/broker.dart';

class LoadEntryForm extends ConsumerStatefulWidget {
  final Future<void> Function(Load load) onSave;
  final VoidCallback onCancel;
  final Future<Broker?> Function() onAddBroker;

  const LoadEntryForm({
    super.key,
    required this.onSave,
    required this.onCancel,
    required this.onAddBroker,
  });

  @override
  ConsumerState<LoadEntryForm> createState() => _LoadEntryFormState();
}

class _LoadEntryFormState extends ConsumerState<LoadEntryForm> {
  Broker? _selectedBroker;
  late List<Broker> _localBrokers;

  bool _isSaving = false;
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _tripController = TextEditingController();
  final TextEditingController _goodsController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _loadNotesController = TextEditingController();
  final TextEditingController _companyNotesController = TextEditingController();

  // Suggestions for pickup locations and receivers
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _receiverSuggestions = [];

  @override
  void initState() {
    super.initState();
    _localBrokers = []; // Start empty, will fetch in _fetchLocationSuggestions

    // Initialize controllers with draft values
    final draft = ref.read(loadDraftProvider);
    _refController.text = draft.loadReference;
    _tripController.text = draft.tripNumber;
    _goodsController.text = draft.goods;
    _quantityController.text = draft.quantity;
    _loadNotesController.text = draft.loadNotes;
    _companyNotesController.text = draft.companyNotes;

    // Attempt to match selected broker from draft name
    if (draft.brokerName.isNotEmpty) {
      try {
        _selectedBroker = _localBrokers.firstWhere(
          (b) => b.name == draft.brokerName,
        );
        _brokerController.text = _selectedBroker!.name;
      } catch (_) {
        _brokerController.text = draft.brokerName;
      }
    }

    // Fetch pickup locations and receivers for auto-suggest
    _fetchLocationSuggestions();
    _autoPopulateTripNumber();
  }

  Future<void> _autoPopulateTripNumber() async {
    // If the field is already populated (e.g. editing an existing load), don't overwrite
    if (_tripController.text.isNotEmpty) return;

    try {
      final nextTrip = await ref
          .read(loadRepositoryProvider)
          .getNextTripNumber();
      if (mounted && nextTrip != null && _tripController.text.isEmpty) {
        setState(() {
          _tripController.text = nextTrip;
        });
        _updateDraft((l) => l.copyWith(tripNumber: nextTrip));
      }
    } catch (e) {
      debugPrint('Error auto-populating trip number: $e');
    }
  }

  Future<void> _fetchLocationSuggestions() async {
    try {
      // Fetch unique pickup locations (shippers)
      final pickups = await Supabase.instance.client
          .from('pickups')
          .select(
            'id, shipper_name, address, city, state_province, postal_code, contact_person, phone, fax',
          )
          .order('shipper_name');

      // Fetch unique receivers
      final receivers = await Supabase.instance.client
          .from('receivers')
          .select(
            'id, receiver_name, address, city, state_province, postal_code, contact_person, phone, fax',
          )
          .order('receiver_name');

      // Fetch broker-type customers from customers table
      final brokerCustomers = await Supabase.instance.client
          .from('customers')
          .select('id, name, city, state_province')
          .eq('customer_type', 'Broker')
          .order('name');

      if (mounted) {
        // Remove duplicates by company name
        final seenPickups = <String>{};
        final seenReceivers = <String>{};

        // Add broker customers to local brokers list if not already present
        final existingBrokerNames = _localBrokers
            .map((b) => b.name.toLowerCase())
            .toSet();
        for (final broker in List<Map<String, dynamic>>.from(brokerCustomers)) {
          final name = broker['name'] as String? ?? '';
          if (name.isNotEmpty &&
              !existingBrokerNames.contains(name.toLowerCase())) {
            _localBrokers.add(
              Broker(
                id: broker['id'] as String? ?? '',
                name: name,
                mcNumber: '',
                dotNumber: '',
                phoneNumber: '',
                email: '',
                address: '',
                city: broker['city'] as String? ?? '',
                state: broker['state_province'] as String? ?? '',
                zipCode: '',
                country: '',
                notes: '',
              ),
            );
            existingBrokerNames.add(name.toLowerCase());
          }
        }

        setState(() {
          _pickupSuggestions = List<Map<String, dynamic>>.from(
            pickups,
          ).where((p) => seenPickups.add(p['shipper_name'] ?? '')).toList();
          _receiverSuggestions = List<Map<String, dynamic>>.from(
            receivers,
          ).where((r) => seenReceivers.add(r['receiver_name'] ?? '')).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching location suggestions: $e');
    }
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _refController.dispose();
    _tripController.dispose();
    _goodsController.dispose();
    _quantityController.dispose();
    _loadNotesController.dispose();
    _companyNotesController.dispose();
    super.dispose();
  }

  void _updateDraft(Load Function(Load) update) {
    ref.read(loadDraftProvider.notifier).update(update);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final draft = ref.watch(loadDraftProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Button(
                    onPressed: widget.onCancel,
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
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Broker Name',
                  child: AutoSuggestBox<Broker>(
                    controller: _brokerController,
                    placeholder: 'Search or Add Broker',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: _getBrokerSuggestions(),
                    onSelected: (item) => _onBrokerChanged(item.value),
                    onChanged: (text, reason) {
                      if (reason == TextChangedReason.userInput) {
                        _updateDraft(
                          (l) => l.copyWith(brokerName: text, brokerId: null),
                        );
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Load Ref #',
                  child: TextBox(
                    controller: _refController,
                    placeholder: 'Broker Reference Number',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(loadReference: value)),
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Trip #',
                  child: TextBox(
                    controller: _tripController,
                    placeholder: 'Internal Trip Number',
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(tripNumber: value)),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InfoLabel(
                        label: 'Broker Name',
                        child: AutoSuggestBox<Broker>(
                          controller: _brokerController,
                          placeholder: 'Search or Add Broker',
                          items: _getBrokerSuggestions(),
                          onSelected: (item) => _onBrokerChanged(item.value),
                          onChanged: (text, reason) {
                            if (reason == TextChangedReason.userInput) {
                              _updateDraft(
                                (l) => l.copyWith(
                                  brokerName: text,
                                  brokerId: null,
                                ),
                              );
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InfoLabel(
                        label: 'Load Ref #',
                        child: TextBox(
                          controller: _refController,
                          placeholder: 'Broker Ref',
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(loadReference: value),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InfoLabel(
                        label: 'Trip #',
                        child: TextBox(
                          controller: _tripController,
                          placeholder: 'Trip Number',
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(tripNumber: value),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Rate',
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: NumberBox<double>(
                          value: draft.rate,
                          decoration: WidgetStateProperty.all(
                            BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(rate: value ?? 0.0),
                          ),
                          mode: SpinButtonPlacementMode.none,
                          placeholder: 'Amount',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: ComboBox<String>(
                          value: draft.currency,
                          items: const [
                            ComboBoxItem(value: 'CAD', child: Text('CAD')),
                            ComboBoxItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _updateDraft((l) => l.copyWith(currency: value));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Goods / Commodity',
                  child: TextBox(
                    controller: _goodsController,
                    placeholder: 'Description of cargo',
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(goods: value)),
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Weight',
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: NumberBox<double>(
                          value: draft.weight,
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(weight: value ?? 0.0),
                          ),
                          mode: SpinButtonPlacementMode.none,
                          placeholder: 'Weight',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: ComboBox<String>(
                          value: draft.weightUnit,
                          items: const [
                            ComboBoxItem(value: 'Lbs', child: Text('Lbs')),
                            ComboBoxItem(value: 'Kgs', child: Text('Kgs')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _updateDraft(
                                (l) => l.copyWith(weightUnit: value),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Quantity',
                  child: TextBox(
                    controller: _quantityController,
                    placeholder: 'e.g. 24 Pallets',
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(quantity: value)),
                  ),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: 'Rate',
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: NumberBox<double>(
                                value: draft.rate,
                                onChanged: (value) => _updateDraft(
                                  (l) => l.copyWith(rate: value ?? 0.0),
                                ),
                                mode: SpinButtonPlacementMode.none,
                                placeholder: 'Amount',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: ComboBox<String>(
                                value: draft.currency,
                                items: const [
                                  ComboBoxItem(
                                    value: 'CAD',
                                    child: Text('CAD'),
                                  ),
                                  ComboBoxItem(
                                    value: 'USD',
                                    child: Text('USD'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    _updateDraft(
                                      (l) => l.copyWith(currency: value),
                                    );
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
                          controller: _goodsController,
                          placeholder: 'Description of cargo',
                          onChanged: (value) =>
                              _updateDraft((l) => l.copyWith(goods: value)),
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
                      label: 'Weight',
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: NumberBox<double>(
                              value: draft.weight,
                              onChanged: (value) => _updateDraft(
                                (l) => l.copyWith(weight: value ?? 0.0),
                              ),
                              mode: SpinButtonPlacementMode.none,
                              placeholder: 'Weight',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: ComboBox<String>(
                              value: draft.weightUnit,
                              items: const [
                                ComboBoxItem(value: 'Lbs', child: Text('Lbs')),
                                ComboBoxItem(value: 'Kgs', child: Text('Kgs')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _updateDraft(
                                    (l) => l.copyWith(weightUnit: value),
                                  );
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
                      label: 'Quantity',
                      child: TextBox(
                        controller: _quantityController,
                        placeholder: 'e.g. 24 Pallets',
                        onChanged: (value) =>
                            _updateDraft((l) => l.copyWith(quantity: value)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Trip Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                AddressInputForm(
                  title: 'Pick up',
                  location: draft.pickup,
                  onChanged: (v) => _updateDraft((l) => l.copyWith(pickup: v)),
                  suggestions: _pickupSuggestions,
                  isPickup: true,
                ),
                const SizedBox(height: 16),
                AddressInputForm(
                  title: 'Delivery',
                  location: draft.delivery,
                  onChanged: (v) =>
                      _updateDraft((l) => l.copyWith(delivery: v)),
                  suggestions: _receiverSuggestions,
                  isPickup: false,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AddressInputForm(
                        title: 'Pick up',
                        location: draft.pickup,
                        onChanged: (v) =>
                            _updateDraft((l) => l.copyWith(pickup: v)),
                        suggestions: _pickupSuggestions,
                        isPickup: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AddressInputForm(
                        title: 'Delivery',
                        location: draft.delivery,
                        onChanged: (v) =>
                            _updateDraft((l) => l.copyWith(delivery: v)),
                        suggestions: _receiverSuggestions,
                        isPickup: false,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Company Notes',
                  child: TextBox(
                    controller: _companyNotesController,
                    placeholder: 'Notes about the company/broker',
                    maxLines: 3,
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(companyNotes: value)),
                  ),
                ),
              ] else
                InfoLabel(
                  label: 'Company Notes',
                  child: TextBox(
                    controller: _companyNotesController,
                    placeholder: 'Notes about the company/broker',
                    maxLines: 3,
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(companyNotes: value)),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final draft = ref.read(loadDraftProvider);
    if (draft.brokerName.isEmpty ||
        draft.loadReference.isEmpty ||
        draft.rate <= 0) {
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

    try {
      await widget.onSave(draft);
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error Saving Load'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<AutoSuggestBoxItem<Broker>> _getBrokerSuggestions() {
    final query = _brokerController.text.toLowerCase();

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

    final addLabel = query.isEmpty ? '+ Add New Broker' : '+ Add "$query"';

    filtered.add(
      AutoSuggestBoxItem<Broker>(
        value: null,
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
      final newBroker = await widget.onAddBroker();
      if (newBroker != null) {
        setState(() {
          _localBrokers.add(newBroker);
          _selectedBroker = newBroker;
          _brokerController.text = newBroker.name;
        });
        _updateDraft(
          (l) => l.copyWith(brokerId: newBroker.id, brokerName: newBroker.name),
        );
      }
    } else {
      setState(() {
        _selectedBroker = value;
        _brokerController.text = value.name;
      });
      _updateDraft(
        (l) => l.copyWith(brokerId: value.id, brokerName: value.name),
      );
    }
  }
}
