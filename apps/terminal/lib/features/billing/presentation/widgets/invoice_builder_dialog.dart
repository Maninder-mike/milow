import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dispatch/domain/models/load.dart';
import '../../domain/models/invoice.dart';
import '../providers/invoice_providers.dart';

class InvoiceBuilderDialog extends ConsumerStatefulWidget {
  final Load load;

  const InvoiceBuilderDialog({super.key, required this.load});

  @override
  ConsumerState<InvoiceBuilderDialog> createState() =>
      _InvoiceBuilderDialogState();
}

class _InvoiceBuilderDialogState extends ConsumerState<InvoiceBuilderDialog> {
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final List<InvoiceLineItem> _lineItems = [];
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    // Pre-populate with Load data
    _lineItems.add(
      InvoiceLineItem(
        type: 'Linehaul',
        description: 'Freight charges for Load #${widget.load.loadReference}',
        rate: widget.load.rate,
        quantity: 1,
        unit: 'flat',
      ),
    );
    _invoiceNumberController.text = 'PENDING'; // Or fetch next number
    _fetchNextInvoiceNumber();
  }

  Future<void> _fetchNextInvoiceNumber() async {
    final repository = ref.read(invoiceRepositoryProvider);
    final nextNum = await repository.getNextInvoiceNumber();
    if (mounted) {
      setState(() {
        _invoiceNumberController.text = nextNum;
      });
    }
  }

  double get _subtotal => _lineItems.fold(0, (sum, item) => sum + item.total);
  double get _total => _subtotal; // Add tax logic later if needed

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Generate Invoice for #${widget.load.loadReference}'),
      constraints: const BoxConstraints(maxWidth: 600),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Invoice #',
                    child: TextBox(controller: _invoiceNumberController),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Issue Date',
                    child: DatePicker(
                      selected: _issueDate,
                      onChanged: (date) => setState(() => _issueDate = date),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Due Date',
              child: DatePicker(
                selected: _dueDate,
                onChanged: (date) => setState(() => _dueDate = date),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Line Items',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ..._lineItems.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(item.description)),
                    Expanded(flex: 1, child: Text('${item.rate}')),
                    Expanded(flex: 1, child: Text('x${item.quantity}')),
                    Text(
                      '${item.total}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Total: \$$_total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                maxLines: 3,
                placeholder: 'Payment instructions, terms, etc.',
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
          onPressed: () async {
            try {
              final invoice = Invoice(
                id: '',
                loadId: widget.load.id,
                customerId: widget.load.brokerId,
                invoiceNumber: _invoiceNumberController.text,
                status: 'draft',
                lineItems: _lineItems,
                subtotal: _subtotal,
                totalAmount: _total,
                issueDate: _issueDate,
                dueDate: _dueDate,
                notes: _notesController.text,
              );

              await ref
                  .read(invoiceControllerProvider.notifier)
                  .createInvoice(invoice);
              if (!context.mounted) return;
              Navigator.pop(context);
            } catch (e) {
              debugPrint('Error creating invoice: $e');
              if (!context.mounted) return;
              await showDialog(
                context: context,
                builder: (context) => ContentDialog(
                  title: const Text('Error Creating Invoice'),
                  content: Text('Failed to create invoice: $e'),
                  actions: [
                    Button(
                      child: const Text('Close'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
          },
          child: const Text('Create Invoice'),
        ),
      ],
    );
  }
}
