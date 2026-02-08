import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:terminal/features/dispatch/domain/models/accessorial_charge.dart';

class AccessorialsWidget extends StatefulWidget {
  final List<AccessorialCharge> charges;
  final Function(AccessorialCharge) onAdd;
  final Function(AccessorialCharge) onDelete;
  final bool isReadOnly;

  const AccessorialsWidget({
    super.key,
    required this.charges,
    required this.onAdd,
    required this.onDelete,
    this.isReadOnly = false,
  });

  @override
  State<AccessorialsWidget> createState() => _AccessorialsWidgetState();
}

class _AccessorialsWidgetState extends State<AccessorialsWidget> {
  void _openAddDialog() {
    String type = 'Detention';
    String amountStr = '';
    String notes = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Add Accessorial Charge'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLabel(
                  label: 'Type',
                  child: ComboBox<String>(
                    value: type,
                    items:
                        const [
                          'Detention',
                          'Lumper',
                          'Layover',
                          'Tarp',
                          'Scale',
                          'Other',
                        ].map((e) {
                          return ComboBoxItem(value: e, child: Text(e));
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        type = val;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Amount',
                  child: TextFormBox(
                    placeholder: '0.00',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text('\$'),
                    ),
                    onChanged: (val) => amountStr = val,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Notes (Optional)',
                  child: TextFormBox(
                    placeholder: 'Reason for charge...',
                    onChanged: (val) => notes = val,
                    maxLines: 2,
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
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  final charge = AccessorialCharge.create(
                    loadId: '', // Will be assigned by parent or controller
                    type: type,
                    amount: double.parse(amountStr),
                    notes: notes,
                  );
                  widget.onAdd(charge);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Charge'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Accessorials & Extra Charges',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (!widget.isReadOnly)
              Button(
                onPressed: _openAddDialog, // Fixed: Pass function reference
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 12),
                    SizedBox(width: 8),
                    Text('Add Charge'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.charges.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FluentTheme.of(
                context,
              ).resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: FluentTheme.of(
                  context,
                ).resources.surfaceStrokeColorDefault,
              ),
            ),
            width: double.infinity,
            child: Text(
              'No additional charges recorded.',
              style: TextStyle(
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            children: widget.charges.map((charge) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FluentIcons.money,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charge.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (charge.notes.isNotEmpty)
                              Text(
                                charge.notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FluentTheme.of(
                                    context,
                                  ).resources.textFillColorSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(charge.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'RobotoMono', // Monospace for numbers
                        ),
                      ),
                      if (!widget.isReadOnly) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(FluentIcons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return ContentDialog(
                                  title: const Text('Delete Charge?'),
                                  content: const Text(
                                    'Are you sure you want to remove this charge?',
                                  ),
                                  actions: [
                                    Button(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all(Colors.red),
                                      ),
                                      onPressed: () {
                                        widget.onDelete(charge);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
