import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/manifest.dart';
import '../providers/brokerage_providers.dart';

class ManifestEntryDialog extends ConsumerStatefulWidget {
  final Future<void> Function(Manifest manifest) onSave;
  final Manifest? initialManifest;
  final String companyId;

  const ManifestEntryDialog({
    super.key,
    required this.onSave,
    this.initialManifest,
    required this.companyId,
  });

  @override
  ConsumerState<ManifestEntryDialog> createState() => _ManifestEntryDialogState();
}

class _ManifestEntryDialogState extends ConsumerState<ManifestEntryDialog> {
  late TextEditingController _manifestNumberController;
  late TextEditingController _agreedCostController;
  late TextEditingController _notesController;
  late TextEditingController _currencyController;

  String? _selectedPartnerId;
  ManifestStatus _status = ManifestStatus.draft;
  DateTime? _scheduledPickup;
  DateTime? _scheduledDelivery;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final manifest = widget.initialManifest;
    _manifestNumberController = TextEditingController(
      text: manifest != null ? manifest.manifestNumber.toString() : '',
    );
    _agreedCostController = TextEditingController(
      text: manifest != null ? manifest.agreedCost.toStringAsFixed(2) : '0.00',
    );
    _notesController = TextEditingController(text: manifest?.notes ?? '');
    _currencyController = TextEditingController(text: manifest?.currency ?? 'USD');

    _selectedPartnerId = manifest?.partnerId;
    _status = manifest?.status ?? ManifestStatus.draft;
    _scheduledPickup = manifest?.scheduledPickup;
    _scheduledDelivery = manifest?.scheduledDelivery;
  }

  @override
  void dispose() {
    _manifestNumberController.dispose();
    _agreedCostController.dispose();
    _notesController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(brokeragePartnersProvider);

    return ContentDialog(
      title: Text(
        widget.initialManifest == null ? 'New Manifest' : 'Edit Manifest',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'General Information',
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              child: const Divider(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Manifest Number',
                    child: TextBox(
                      placeholder: 'Auto-generated if empty',
                      controller: _manifestNumberController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Status',
                    child: ComboBox<ManifestStatus>(
                      value: _status,
                      isExpanded: true,
                      items: ManifestStatus.values
                          .map((e) => ComboBoxItem(value: e, child: Text(e.label)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Brokerage Partner *',
              child: partnersAsync.when(
                data: (partners) {
                  if (partners.isEmpty) {
                    return Text(
                      'No partners available. Please add a partner first.',
                      style: TextStyle(color: Colors.red.normal),
                    );
                  }

                  // Fallback: If selected partner ID is not in active list, reset
                  final containsSelected = partners.any((p) => p.id == _selectedPartnerId);
                  if (_selectedPartnerId != null && !containsSelected) {
                    _selectedPartnerId = null;
                  }

                  // Select first partner if none selected
                  if (_selectedPartnerId == null && partners.isNotEmpty) {
                    _selectedPartnerId = partners.first.id;
                  }

                  return ComboBox<String>(
                    value: _selectedPartnerId,
                    isExpanded: true,
                    items: partners
                        .map((p) => ComboBoxItem(value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedPartnerId = val);
                    },
                  );
                },
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error loading partners: $e', style: TextStyle(color: Colors.red.normal)),
              ),
            ),
            const SizedBox(height: 20),
            InfoLabel(
              label: 'Financials & Scheduling',
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              child: const Divider(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'Agreed Cost *',
                    child: TextBox(
                      placeholder: '0.00',
                      controller: _agreedCostController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: InfoLabel(
                    label: 'Currency',
                    child: TextBox(
                      placeholder: 'USD',
                      controller: _currencyController,
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
                    label: 'Scheduled Pickup',
                    child: Row(
                      children: [
                        Checkbox(
                          checked: _scheduledPickup != null,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _scheduledPickup = DateTime.now();
                              } else {
                                _scheduledPickup = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_scheduledPickup != null)
                          Expanded(
                            child: DatePicker(
                              selected: _scheduledPickup!,
                              onChanged: (date) {
                                setState(() => _scheduledPickup = date);
                              },
                            ),
                          )
                        else
                          const Text('Not Set', style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Scheduled Delivery',
                    child: Row(
                      children: [
                        Checkbox(
                          checked: _scheduledDelivery != null,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _scheduledDelivery = DateTime.now();
                              } else {
                                _scheduledDelivery = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_scheduledDelivery != null)
                          Expanded(
                            child: DatePicker(
                              selected: _scheduledDelivery!,
                              onChanged: (date) {
                                setState(() => _scheduledDelivery = date);
                              },
                            ),
                          )
                        else
                          const Text('Not Set', style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                placeholder: 'Additional manifest instructions...',
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
          child: Text('Cancel', style: GoogleFonts.outfit()),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: ProgressRing())
              : Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedPartnerId == null) {
      displayInfoBar(
        alignment: Alignment.bottomRight,
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('Invalid Input', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            content: Text('A Brokerage Partner must be selected.', style: GoogleFonts.outfit()),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    final manifestNum = int.tryParse(_manifestNumberController.text.trim()) ?? 0;
    final cost = double.tryParse(_agreedCostController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final manifest = Manifest(
      id: widget.initialManifest?.id ?? '',
      companyId: widget.companyId,
      manifestNumber: manifestNum,
      partnerId: _selectedPartnerId!,
      status: _status,
      agreedCost: cost,
      currency: _currencyController.text.trim().isEmpty ? 'USD' : _currencyController.text.trim(),
      scheduledPickup: _scheduledPickup,
      scheduledDelivery: _scheduledDelivery,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.initialManifest?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.onSave(manifest);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }
}
