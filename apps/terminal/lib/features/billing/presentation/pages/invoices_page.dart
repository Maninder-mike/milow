import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/invoice_providers.dart';
import '../../domain/models/invoice.dart';
import '../../../../core/constants/app_colors.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final invoicesAsync = ref.watch(
      invoicesListProvider(statusFilter: _statusFilter),
    );

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Invoices'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.filter_24_regular),
              label: Text(_statusFilter),
              onPressed: () => _showFilterMenu(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
              onPressed: () => ref.invalidate(invoicesListProvider),
            ),
          ],
        ),
      ),
      content: invoicesAsync.when(
        data: (invoices) => _buildInvoiceTable(invoices, theme),
        loading: () => const Center(child: ProgressRing()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showFilterMenu(BuildContext context) {
    // Basic filter menu logic
    setState(() {
      _statusFilter = _statusFilter == 'All' ? 'draft' : 'All';
    });
  }

  Widget _buildInvoiceTable(List<Invoice> invoices, FluentThemeData theme) {
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices found.'));
    }

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.surfaceStrokeColorDefault.withValues(
            alpha: 0.05,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            color: theme.resources.surfaceStrokeColorDefault.withValues(
              alpha: 0.03,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildHeaderCell('Invoice #', flex: 2),
                _buildHeaderCell('Date', flex: 2),
                _buildHeaderCell('Customer', flex: 4),
                _buildHeaderCell('Total', flex: 2),
                _buildHeaderCell('Status', flex: 2),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('MM/dd/yy').format(invoice.issueDate),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(invoice.customerId ?? 'Unknown'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '\$${invoice.totalAmount.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusChip(invoice.status),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: FluentTheme.of(context).resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.neutral;
    if (status == 'draft') color = AppColors.info;
    if (status == 'paid') color = AppColors.success;
    if (status == 'overdue') color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
