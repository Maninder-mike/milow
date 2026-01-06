import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/load_providers.dart';
import 'address_input_form.dart';
import '../../domain/models/load.dart';
import '../../domain/models/broker.dart';

class LoadEntryForm extends ConsumerStatefulWidget {
  final Future<void> Function(Load load) onSave;
  final VoidCallback onCancel;
  final List<Broker> brokers;
  final Future<Broker?> Function() onAddBroker;

  const LoadEntryForm({
    super.key,
    required this.onSave,
    required this.onCancel,
    required this.brokers,
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
  final TextEditingController _goodsController = TextEditingController();
  final TextEditingController _loadNotesController = TextEditingController();
  final TextEditingController _companyNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localBrokers = List.from(widget.brokers);

    // Initialize controllers with draft values
    final draft = ref.read(loadDraftProvider);
    _refController.text = draft.loadReference;
    _goodsController.text = draft.goods;
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
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _refController.dispose();
    _goodsController.dispose();
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
              const Text(
                'Broker Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Broker Name',
                  child: AutoSuggestBox<Broker>(
                    controller: _brokerController,
                    placeholder: 'Search or Add Broker',
                    items: _getBrokerSuggestions(),
                    onSelected: (item) {
                      if (item.value == null) {
                        _onBrokerChanged(null);
                      } else {
                        setState(() {
                          _selectedBroker = item.value;
                        });
                        _updateDraft(
                          (l) => l.copyWith(brokerName: item.value!.name),
                        );
                      }
                    },
                    onChanged: (text, reason) {
                      if (reason == TextChangedReason.userInput) {
                        if (_selectedBroker != null &&
                            text != _selectedBroker!.name) {
                          setState(() {
                            _selectedBroker = null;
                          });
                        }
                        _updateDraft((l) => l.copyWith(brokerName: text));
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
                    placeholder: 'Reference Number',
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(loadReference: value)),
                  ),
                ),
              ] else
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
                              _onBrokerChanged(null);
                            } else {
                              setState(() {
                                _selectedBroker = item.value;
                              });
                              _updateDraft(
                                (l) => l.copyWith(brokerName: item.value!.name),
                              );
                            }
                          },
                          onChanged: (text, reason) {
                            if (reason == TextChangedReason.userInput) {
                              if (_selectedBroker != null &&
                                  text != _selectedBroker!.name) {
                                setState(() {
                                  _selectedBroker = null;
                                });
                              }
                              _updateDraft((l) => l.copyWith(brokerName: text));
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
                          controller: _refController,
                          placeholder: 'Reference Number',
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(loadReference: value),
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
                    placeholder: 'e.g. General Freight, Produce',
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(goods: value)),
                  ),
                ),
              ] else
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
                          placeholder: 'e.g. General Freight, Produce',
                          onChanged: (value) =>
                              _updateDraft((l) => l.copyWith(goods: value)),
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
                ),
                const SizedBox(height: 16),
                AddressInputForm(
                  title: 'Delivery',
                  location: draft.delivery,
                  onChanged: (v) =>
                      _updateDraft((l) => l.copyWith(delivery: v)),
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AddressInputForm(
                        title: 'Delivery',
                        location: draft.delivery,
                        onChanged: (v) =>
                            _updateDraft((l) => l.copyWith(delivery: v)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                InfoLabel(
                  label: 'Load Notes',
                  child: TextBox(
                    controller: _loadNotesController,
                    placeholder: 'Notes specific to this load',
                    maxLines: 3,
                    onChanged: (value) =>
                        _updateDraft((l) => l.copyWith(loadNotes: value)),
                  ),
                ),
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
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: 'Load Notes',
                        child: TextBox(
                          controller: _loadNotesController,
                          placeholder: 'Notes specific to this load',
                          maxLines: 3,
                          onChanged: (value) =>
                              _updateDraft((l) => l.copyWith(loadNotes: value)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InfoLabel(
                        label: 'Company Notes',
                        child: TextBox(
                          controller: _companyNotesController,
                          placeholder: 'Notes about the company/broker',
                          maxLines: 3,
                          onChanged: (value) => _updateDraft(
                            (l) => l.copyWith(companyNotes: value),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
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

    await widget.onSave(draft);

    if (mounted) {
      setState(() => _isSaving = false);
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
      }
    } else {
      setState(() {
        _selectedBroker = value;
        _brokerController.text = value.name;
      });
    }
  }
}
