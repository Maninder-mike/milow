import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/load_providers.dart';
import 'address_input_form.dart';
import '../../domain/models/load.dart';

import 'package:terminal/features/dispatch/domain/models/accessorial_charge.dart';
import '../widgets/accessorials_widget.dart';
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
  // Controllers strictly for header fields that are text inputs
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _tripController = TextEditingController();
  final TextEditingController _goodsController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _companyNotesController = TextEditingController();
  final TextEditingController _poController = TextEditingController();
  // Rate controllers
  // We use immediate updates for these usually, or controllers synced with draft.

  // Suggestions for pickup locations and receivers
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _receiverSuggestions = [];

  @override
  void initState() {
    super.initState();
    _localBrokers = [];

    // Initialize controllers with draft values
    final draft = ref.read(loadDraftProvider);
    _refController.text = draft.loadReference;
    _tripController.text = draft.tripNumber;
    _goodsController.text = draft.goods;
    _quantityController.text = draft.quantity;
    _companyNotesController.text = draft.companyNotes;
    _poController.text = draft.poNumber ?? '';

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

    _fetchLocationSuggestions();
    _autoPopulateTripNumber();
  }

  Future<void> _autoPopulateTripNumber() async {
    if (_tripController.text.isNotEmpty) return;

    final result = await ref.read(loadRepositoryProvider).getNextTripNumber();

    result.fold(
      (failure) {
        debugPrint('Error auto-populating trip number: ${failure.message}');
      },
      (nextTrip) {
        if (mounted && nextTrip != null && _tripController.text.isEmpty) {
          setState(() {
            _tripController.text = nextTrip;
          });
          _updateDraft((l) => l.copyWith(tripNumber: nextTrip));
        }
      },
    );
  }

  Future<void> _fetchLocationSuggestions() async {
    try {
      final pickups = await Supabase.instance.client
          .from('pickups')
          .select(
            'id, shipper_name, address, city, state_province, postal_code, contact_person, phone, fax',
          )
          .order('shipper_name');

      final receivers = await Supabase.instance.client
          .from('receivers')
          .select(
            'id, receiver_name, address, city, state_province, postal_code, contact_person, phone, fax',
          )
          .order('receiver_name');

      final brokerCustomers = await Supabase.instance.client
          .from('customers')
          .select('id, name, city, state_province')
          .eq('customer_type', 'Broker')
          .order('name');

      if (mounted) {
        final seenPickups = <String>{};
        final seenReceivers = <String>{};

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
    _companyNotesController.dispose();
    _poController.dispose();
    super.dispose();
  }

  void _updateDraft(Load Function(Load) update) {
    ref.read(loadDraftProvider.notifier).update(update);
  }

  // --- Multi-Stop Logic ---

  void _onReorderSubset(StopType type, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;

    final draft = ref.read(loadDraftProvider);

    // Split into groups
    final pickups = draft.stops
        .where((s) => s.type == StopType.pickup)
        .toList();
    final deliveries = draft.stops
        .where((s) => s.type == StopType.delivery)
        .toList();

    // Reorder the target group
    final targetList = (type == StopType.pickup) ? pickups : deliveries;
    final item = targetList.removeAt(oldIndex);
    targetList.insert(newIndex, item);

    // Reconstruct full list: ALWAYS Pickups then Deliveries
    final newStops = [...pickups, ...deliveries];

    // Re-sequence globally
    final resequencedStops = newStops.asMap().entries.map((e) {
      return e.value.copyWith(sequence: e.key + 1);
    }).toList();

    _updateDraft((l) => l.copyWith(stops: resequencedStops));
  }

  void _addStop(StopType type) {
    var stops = List<Stop>.from(ref.read(loadDraftProvider).stops);

    // Auto-fill logic for Delivery
    String? commodity;
    String? quantity;
    double? weight;
    String? weightUnit;
    String? instructions;
    String? stopReference;

    if (type == StopType.delivery) {
      final pickups = stops.where((s) => s.type == StopType.pickup).toList();
      final deliveryCount = stops
          .where((s) => s.type == StopType.delivery)
          .length;

      if (pickups.isNotEmpty) {
        if (deliveryCount == 0) {
          // Aggregate all pickups for the first delivery
          double totalWeight = 0;
          List<String> commodities = [];
          List<String> quantities = [];
          List<String> refs = [];
          String? commonUnit;

          for (var p in pickups) {
            if (p.weight != null) totalWeight += p.weight!;
            if (p.commodity != null && p.commodity!.isNotEmpty) {
              commodities.add(p.commodity!);
            }
            if (p.quantity != null && p.quantity!.isNotEmpty) {
              quantities.add(p.quantity!);
            }
            if (p.stopReference != null && p.stopReference!.isNotEmpty) {
              refs.add(p.stopReference!);
            }
            commonUnit ??= p.weightUnit;
          }

          commodity = commodities.join(', ');
          weight = totalWeight > 0 ? totalWeight : null;
          weightUnit = commonUnit;
          stopReference = refs.join(', ');

          // Sum quantities if they look like numbers
          try {
            double qSum = 0;
            bool allNumeric = true;
            for (var q in quantities) {
              final val = double.tryParse(q.replaceAll(RegExp(r'[^0-9.]'), ''));
              if (val != null) {
                qSum += val;
              } else {
                allNumeric = false;
                break;
              }
            }
            if (allNumeric && quantities.isNotEmpty) {
              quantity = qSum.toStringAsFixed(0);
              // If there was a common suffix (e.g. " Pallets"), try to preserve it
              if (quantities.first.toLowerCase().contains('pallet')) {
                quantity += ' Pallets';
              }
            } else {
              quantity = quantities.join(', ');
            }
          } catch (_) {
            quantity = quantities.join(', ');
          }
        } else {
          // Default to last pickup for subsequent deliveries
          final lastPickup = pickups.last;
          commodity = lastPickup.commodity;
          quantity = lastPickup.quantity;
          weight = lastPickup.weight;
          weightUnit = lastPickup.weightUnit;
          instructions = lastPickup.instructions;
          stopReference = lastPickup.stopReference;
        }
      }
    }

    stops.add(
      Stop(
        id: 'new_${DateTime.now().microsecondsSinceEpoch}',
        loadId: '',
        sequence: stops.length + 1,
        type: type,
        location: LoadLocation.empty(),
        commodity: commodity,
        quantity: quantity,
        weight: weight,
        weightUnit: weightUnit,
        instructions: instructions,
        stopReference: stopReference,
      ),
    );
    _updateDraft((l) => l.copyWith(stops: stops));
  }

  void _removeStop(int index) {
    var stops = List<Stop>.from(ref.read(loadDraftProvider).stops);
    stops.removeAt(index);
    // Re-sequence
    final updatedStops = stops.asMap().entries.map((e) {
      return e.value.copyWith(sequence: e.key + 1);
    }).toList();
    _updateDraft((l) => l.copyWith(stops: updatedStops));
  }

  void _updateStopLocation(int index, LoadLocation newLocation) {
    var stops = List<Stop>.from(ref.read(loadDraftProvider).stops);
    stops[index] = stops[index].copyWith(
      location: newLocation,
      appointmentTime:
          newLocation.date, // Sync appointmentTime with location date
    );
    _updateDraft((l) => _recalculateTotals(l.copyWith(stops: stops)));
  }

  // Auto-calculate totals from stops
  Load _recalculateTotals(Load draft) {
    // Only auto-calc if there are stops with weight
    final totalWeight = draft.stops.fold<double>(
      0,
      (sum, stop) => sum + (stop.weight ?? 0),
    );

    // If total > 0, update header weight.
    // You might want to respect manual overrides, but for now we sync strictly.
    if (totalWeight > 0) {
      return draft.copyWith(weight: totalWeight);
    }
    return draft;
  }

  Widget _buildPickupsList(Load draft, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Pickups',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: draft.stops.where((s) => s.type == StopType.pickup).length,
          onReorder: (oldIndex, newIndex) =>
              _onReorderSubset(StopType.pickup, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final pickups = draft.stops
                .where((s) => s.type == StopType.pickup)
                .toList();
            final stop = pickups[index];
            final globalIndex = draft.stops.indexOf(stop);

            return Padding(
              key: ValueKey(stop.id.isEmpty ? 'p_$index' : stop.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStopCard(
                globalIndex,
                stop,
                isNarrow,
                showDrag: true,
              ),
            );
          },
        ),
        Button(
          child: const Text('+ Add Pickup'),
          onPressed: () => _addStop(StopType.pickup),
        ),
      ],
    );
  }

  Widget _buildDeliveriesList(Load draft, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Deliveries',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: draft.stops
              .where((s) => s.type == StopType.delivery)
              .length,
          onReorder: (oldIndex, newIndex) =>
              _onReorderSubset(StopType.delivery, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final deliveries = draft.stops
                .where((s) => s.type == StopType.delivery)
                .toList();
            final stop = deliveries[index];
            final globalIndex = draft.stops.indexOf(stop);

            return Padding(
              key: ValueKey(stop.id.isEmpty ? 'd_$index' : stop.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStopCard(
                globalIndex,
                stop,
                isNarrow,
                showDrag: true,
              ),
            );
          },
        ),
        Button(
          child: const Text('+ Add Delivery'),
          onPressed: () => _addStop(StopType.delivery),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final isWide = constraints.maxWidth >= 1200;
        final draft = ref.watch(loadDraftProvider);

        if (_refController.text != draft.loadReference) {
          _refController.text = draft.loadReference;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Actions
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

              // Header Fields
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Broker Name',
                  child: AutoSuggestBox<Broker>(
                    controller: _brokerController,
                    placeholder: 'Search or Add Broker',
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
                Row(
                  children: [
                    Expanded(
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
                      child: InfoLabel(
                        label: 'Trip #',
                        child: TextBox(
                          controller: _tripController,
                          placeholder: 'Trip Number',
                          suffix: IconButton(
                            icon: const Icon(
                              FluentIcons.arrow_clockwise_16_regular,
                            ),
                            onPressed: _autoPopulateTripNumber,
                          ),
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(tripNumber: value),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          placeholder: 'Internal Trip Number',
                          suffix: IconButton(
                            icon: const Icon(
                              FluentIcons.arrow_clockwise_16_regular,
                            ),
                            onPressed: _autoPopulateTripNumber,
                          ),
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(tripNumber: value),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Rate & Goods
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
                                ComboBoxItem(value: 'CAD', child: Text('CAD')),
                                ComboBoxItem(value: 'USD', child: Text('USD')),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: 'PO Number',
                      child: TextBox(
                        controller: _poController,
                        placeholder: 'Customer PO#',
                        onChanged: (value) =>
                            _updateDraft((l) => l.copyWith(poNumber: value)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weight & Qty
              Row(
                children: [
                  if (isWide) ...[
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
                                  ComboBoxItem(
                                    value: 'Lbs',
                                    child: Text('Lbs'),
                                  ),
                                  ComboBoxItem(
                                    value: 'Kgs',
                                    child: Text('Kgs'),
                                  ),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: InfoLabel(
                        label: 'Company Notes',
                        child: TextBox(
                          controller: _companyNotesController,
                          placeholder: 'Internal Notes',
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(companyNotes: value),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
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
                                  ComboBoxItem(
                                    value: 'Lbs',
                                    child: Text('Lbs'),
                                  ),
                                  ComboBoxItem(
                                    value: 'Kgs',
                                    child: Text('Kgs'),
                                  ),
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
                ],
              ),

              const SizedBox(height: 20),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPickupsList(draft, true)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDeliveriesList(draft, true)),
                  ],
                )
              else ...[
                _buildPickupsList(draft, isNarrow),
                const SizedBox(height: 24),
                _buildDeliveriesList(draft, isNarrow),
              ],

              if (!isWide) ...[
                const SizedBox(height: 12),
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
              ],

              const SizedBox(height: 24),

              // Accessorials Section
              AccessorialsWidget(
                charges: draft.accessorials,
                onAdd: (charge) {
                  final updatedList = List<AccessorialCharge>.from(
                    draft.accessorials,
                  )..add(charge);
                  _updateDraft((l) => l.copyWith(accessorials: updatedList));
                },
                onDelete: (charge) {
                  final updatedList = List<AccessorialCharge>.from(
                    draft.accessorials,
                  )..removeWhere((c) => c.id == charge.id);
                  _updateDraft((l) => l.copyWith(accessorials: updatedList));
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopCard(
    int index,
    Stop stop,
    bool isNarrow, {
    bool showDrag = false,
  }) {
    final isPickup = stop.type == StopType.pickup;
    final color = isPickup
        ? Colors.green.withValues(alpha: 0.1)
        : Colors.blue.withValues(alpha: 0.1);
    final borderColor = isPickup ? Colors.green : Colors.blue;
    final title = '${index + 1}. ${isPickup ? "PICKUP" : "DELIVERY"}';

    return Container(
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border.all(
          color: FluentTheme.of(context).resources.cardStrokeColorDefault,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(FluentIcons.list_24_regular),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                  ),
                ),
                const Spacer(),
                if (draftStopsCount > 1) // Allow delete only if multiple
                  IconButton(
                    icon: const Icon(FluentIcons.delete_24_regular, size: 16),
                    onPressed: () => _removeStop(index),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: AddressInputForm(
              title: '', // integrated header
              location: stop.location,
              onChanged: (loc) => _updateStopLocation(index, loc),
              suggestions: isPickup ? _pickupSuggestions : _receiverSuggestions,
              isPickup: isPickup,
            ),
          ),

          if (!isPickup)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Expander(
                header: const Text('Freight Details (Optional)'),
                content: _buildFreightDetailsInputs(index, stop),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _buildFreightDetailsInputs(index, stop),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  int get draftStopsCount => ref.read(loadDraftProvider).stops.length;

  Future<void> _submit() async {
    final draft = ref.read(loadDraftProvider);
    if (draft.brokerName.isEmpty ||
        draft.loadReference.isEmpty ||
        draft.rate <= 0) {
      displayInfoBar(
        context,
        alignment: Alignment.bottomRight,
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

    // Validate Stops
    if (draft.stops.isEmpty) {
      // Warning
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No Stops'),
          content: const Text('At least one stop is required.'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
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

  Widget _buildFreightDetailsInputs(int index, Stop stop) {
    return StopFreightDetails(
      index: index,
      stop: stop,
      onChanged: (updatedStop) {
        var stops = List<Stop>.from(ref.read(loadDraftProvider).stops);
        stops[index] = updatedStop;
        _updateDraft((l) => _recalculateTotals(l.copyWith(stops: stops)));
      },
      onCopyFromPickup: stop.type == StopType.delivery
          ? () {
              final draft = ref.read(loadDraftProvider);
              final pickups = draft.stops
                  .where((s) => s.type == StopType.pickup)
                  .toList();

              if (pickups.isNotEmpty) {
                double totalWeight = 0;
                List<String> commodities = [];
                List<String> quantities = [];
                List<String> refs = [];
                String? commonUnit;

                for (var p in pickups) {
                  if (p.weight != null) totalWeight += p.weight!;
                  if (p.commodity != null && p.commodity!.isNotEmpty) {
                    commodities.add(p.commodity!);
                  }
                  if (p.quantity != null && p.quantity!.isNotEmpty) {
                    quantities.add(p.quantity!);
                  }
                  if (p.stopReference != null && p.stopReference!.isNotEmpty) {
                    refs.add(p.stopReference!);
                  }
                  commonUnit ??= p.weightUnit;
                }

                String finalQuantity = '';
                try {
                  double qSum = 0;
                  bool allNumeric = true;
                  for (var q in quantities) {
                    final val = double.tryParse(
                      q.replaceAll(RegExp(r'[^0-9.]'), ''),
                    );
                    if (val != null) {
                      qSum += val;
                    } else {
                      allNumeric = false;
                    }
                  }
                  if (allNumeric && quantities.isNotEmpty) {
                    finalQuantity = qSum.toStringAsFixed(0);
                    if (quantities.first.toLowerCase().contains('pallet')) {
                      finalQuantity += ' Pallets';
                    }
                  } else {
                    finalQuantity = quantities.join(', ');
                  }
                } catch (_) {
                  finalQuantity = quantities.join(', ');
                }

                var stops = List<Stop>.from(draft.stops);
                stops[index] = stops[index].copyWith(
                  commodity: commodities.join(', '),
                  weight: totalWeight > 0 ? totalWeight : null,
                  weightUnit: commonUnit,
                  quantity: finalQuantity,
                  stopReference: refs.join(', '),
                );
                _updateDraft((l) => l.copyWith(stops: stops));
              }
            }
          : null,
    );
  }
}

class StopFreightDetails extends StatefulWidget {
  final int index;
  final Stop stop;
  final ValueChanged<Stop> onChanged;
  final VoidCallback? onCopyFromPickup;

  const StopFreightDetails({
    super.key,
    required this.index,
    required this.stop,
    required this.onChanged,
    this.onCopyFromPickup,
  });

  @override
  State<StopFreightDetails> createState() => _StopFreightDetailsState();
}

class _StopFreightDetailsState extends State<StopFreightDetails> {
  late TextEditingController _refController;
  late TextEditingController _commodityController;
  late TextEditingController _quantityController;
  late TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: widget.stop.stopReference);
    _commodityController = TextEditingController(text: widget.stop.commodity);
    _quantityController = TextEditingController(text: widget.stop.quantity);
    _instructionsController = TextEditingController(
      text: widget.stop.instructions ?? widget.stop.notes,
    );
  }

  @override
  void didUpdateWidget(StopFreightDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stop.stopReference != oldWidget.stop.stopReference &&
        _refController.text != widget.stop.stopReference) {
      _refController.text = widget.stop.stopReference ?? '';
    }
    if (widget.stop.commodity != oldWidget.stop.commodity &&
        _commodityController.text != widget.stop.commodity) {
      _commodityController.text = widget.stop.commodity ?? '';
    }
    if (widget.stop.quantity != oldWidget.stop.quantity &&
        _quantityController.text != widget.stop.quantity) {
      _quantityController.text = widget.stop.quantity ?? '';
    }
    final currentInstructions = widget.stop.instructions ?? widget.stop.notes;
    final oldInstructions = oldWidget.stop.instructions ?? oldWidget.stop.notes;
    if (currentInstructions != oldInstructions &&
        _instructionsController.text != currentInstructions) {
      _instructionsController.text = currentInstructions ?? '';
    }
  }

  @override
  void dispose() {
    _refController.dispose();
    _commodityController.dispose();
    _quantityController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onCopyFromPickup != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton(
              onPressed: widget.onCopyFromPickup,
              child: const Text('Copy from Pickup'),
            ),
          ),

        // Ref & Commodity
        Row(
          children: [
            Expanded(
              flex: 1,
              child: InfoLabel(
                label: 'Ref / PO #',
                child: TextBox(
                  controller: _refController,
                  placeholder: 'PO# 12345',
                  onChanged: (v) =>
                      widget.onChanged(widget.stop.copyWith(stopReference: v)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InfoLabel(
                label: 'Commodity',
                child: TextBox(
                  controller: _commodityController,
                  placeholder: 'e.g. Frozen Meat',
                  onChanged: (v) =>
                      widget.onChanged(widget.stop.copyWith(commodity: v)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Weight, Unit, Quantity
        Row(
          children: [
            Expanded(
              flex: 2,
              child: InfoLabel(
                label: 'Weight',
                child: NumberBox<double>(
                  value: widget.stop.weight,
                  onChanged: (v) =>
                      widget.onChanged(widget.stop.copyWith(weight: v ?? 0)),
                  placeholder: '0.0',
                  mode: SpinButtonPlacementMode.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: InfoLabel(
                label: 'Unit',
                child: ComboBox<String>(
                  value: widget.stop.weightUnit ?? 'Lbs',
                  items: const [
                    ComboBoxItem(value: 'Lbs', child: Text('Lbs')),
                    ComboBoxItem(value: 'Kgs', child: Text('Kgs')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      widget.onChanged(widget.stop.copyWith(weightUnit: v));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InfoLabel(
                label: 'Quantity',
                child: TextBox(
                  controller: _quantityController,
                  placeholder: '24 Pallets',
                  onChanged: (v) =>
                      widget.onChanged(widget.stop.copyWith(quantity: v)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        InfoLabel(
          label: 'Instructions / Notes',
          child: TextBox(
            controller: _instructionsController,
            placeholder: 'Driver instructions...',
            maxLines: 3,
            onChanged: (v) =>
                widget.onChanged(widget.stop.copyWith(instructions: v)),
          ),
        ),
      ],
    );
  }
}
