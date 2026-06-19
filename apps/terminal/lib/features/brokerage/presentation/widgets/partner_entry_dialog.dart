import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/partner.dart';

class PartnerEntryDialog extends StatefulWidget {
  final Future<void> Function(Partner partner) onSave;
  final Partner? initialPartner;
  final String companyId;

  const PartnerEntryDialog({
    super.key,
    required this.onSave,
    this.initialPartner,
    required this.companyId,
  });

  @override
  State<PartnerEntryDialog> createState() => _PartnerEntryDialogState();
}

class _PartnerEntryDialogState extends State<PartnerEntryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _mcNumberController;
  late TextEditingController _dotNumberController;
  late TextEditingController _scacController;
  late TextEditingController _notesController;
  late TextEditingController _currencyController;

  PartnerStatus _status = PartnerStatus.onboarding;
  SafetyRating _safetyRating = SafetyRating.notRated;
  DateTime? _insuranceExpiration;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final partner = widget.initialPartner;
    _nameController = TextEditingController(text: partner?.name ?? '');
    _mcNumberController = TextEditingController(text: partner?.mcNumber ?? '');
    _dotNumberController = TextEditingController(text: partner?.dotNumber ?? '');
    _scacController = TextEditingController(text: partner?.scac ?? '');
    _notesController = TextEditingController(text: partner?.notes ?? '');
    _currencyController = TextEditingController(text: partner?.currency ?? 'USD');

    _status = partner?.status ?? PartnerStatus.onboarding;
    _safetyRating = partner?.safetyRating ?? SafetyRating.notRated;
    _insuranceExpiration = partner?.insuranceExpiration;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mcNumberController.dispose();
    _dotNumberController.dispose();
    _scacController.dispose();
    _notesController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(
        widget.initialPartner == null ? 'New Partner' : 'Edit Partner',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Identity & Status',
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              child: const Divider(),
            ),
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Partner Name *',
              child: TextBox(
                placeholder: 'Partner Name',
                style: GoogleFonts.outfit(),
                controller: _nameController,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Status',
                    child: ComboBox<PartnerStatus>(
                      value: _status,
                      isExpanded: true,
                      items: PartnerStatus.values
                          .map((e) => ComboBoxItem(value: e, child: Text(e.label)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'Safety Rating',
                    child: ComboBox<SafetyRating>(
                      value: _safetyRating,
                      isExpanded: true,
                      items: SafetyRating.values
                          .map((e) => ComboBoxItem(value: e, child: Text(e.label)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _safetyRating = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InfoLabel(
              label: 'Regulatory Numbers',
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              child: const Divider(),
            ),
            const SizedBox(height: 8),
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
                const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: 'SCAC',
                    child: TextBox(
                      placeholder: 'SCAC',
                      controller: _scacController,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InfoLabel(
              label: 'Insurance & Currency',
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              child: const Divider(),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'Insurance Expiration',
                    child: Row(
                      children: [
                        Checkbox(
                          checked: _insuranceExpiration != null,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _insuranceExpiration = DateTime.now();
                              } else {
                                _insuranceExpiration = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_insuranceExpiration != null)
                          Expanded(
                            child: DatePicker(
                              selected: _insuranceExpiration!,
                              onChanged: (date) {
                                setState(() => _insuranceExpiration = date);
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
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                placeholder: 'Additional notes or requirements...',
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
    if (_nameController.text.trim().isEmpty) {
      displayInfoBar(
        alignment: Alignment.bottomRight,
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('Invalid Input', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            content: Text('Partner Name is required.', style: GoogleFonts.outfit()),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final partner = Partner(
      id: widget.initialPartner?.id ?? '',
      companyId: widget.companyId,
      name: _nameController.text.trim(),
      mcNumber: _mcNumberController.text.trim().isEmpty ? null : _mcNumberController.text.trim(),
      dotNumber: _dotNumberController.text.trim().isEmpty ? null : _dotNumberController.text.trim(),
      scac: _scacController.text.trim().isEmpty ? null : _scacController.text.trim(),
      status: _status,
      safetyRating: _safetyRating,
      insuranceExpiration: _insuranceExpiration,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      currency: _currencyController.text.trim().isEmpty ? 'USD' : _currencyController.text.trim(),
      createdAt: widget.initialPartner?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.onSave(partner);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }
}
