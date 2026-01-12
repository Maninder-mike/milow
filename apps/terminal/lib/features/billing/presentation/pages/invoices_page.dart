import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/invoice_providers.dart';
import '../../domain/models/invoice.dart';
import '../utils/invoice_pdf_generator.dart';
import '../../../settings/providers/company_provider.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  String _statusFilter = 'All';
  String _sortColumn = 'date';
  bool _sortAscending = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final currencyFormat = NumberFormat.currency(symbol: r'$');
  final dateFormat = DateFormat('MM/dd/yy');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final resources = theme.resources;
    final invoicesAsync = ref.watch(
      invoicesListProvider(
        statusFilter: _statusFilter == 'All' ? null : _statusFilter,
      ),
    );

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Invoices'),
        commandBar: _buildCommandBar(context, theme),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Financial Summary Dashboard
          _buildFinancialDashboard(context, theme, invoicesAsync),
          const SizedBox(height: 16),

          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Status Filter Chips
                _buildStatusFilters(theme),
                const Spacer(),
                // Search
                SizedBox(
                  width: 280,
                  child: TextBox(
                    controller: _searchController,
                    placeholder: 'Search invoice #, customer...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search_24_regular, size: 16),
                    ),
                    suffix: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              FluentIcons.dismiss_24_regular,
                              size: 14,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                padding: EdgeInsets.zero,
                backgroundColor: resources.cardBackgroundFillColorDefault,
                child: invoicesAsync.when(
                  data: (invoices) =>
                      _buildInvoiceTable(invoices, theme, resources),
                  loading: () => const Center(child: ProgressRing()),
                  error: (err, _) => _buildErrorState(theme, err.toString()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCommandBar(BuildContext context, FluentThemeData theme) {
    return CommandBar(
      primaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.add_24_regular),
          label: const Text('New Invoice'),
          onPressed: () => _showInvoiceBuilder(context),
        ),
        const CommandBarSeparator(),
        CommandBarButton(
          icon: const Icon(FluentIcons.send_24_regular),
          label: const Text('Send Selected'),
          onPressed: _selectedIds.isEmpty ? null : () => _bulkSend(),
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.arrow_export_24_regular),
          label: const Text('Export CSV'),
          onPressed: () {
            displayInfoBar(
              context,
              builder: (context, close) => const InfoBar(
                title: Text('Export'),
                content: Text(
                  'CSV export will be available in a future update.',
                ),
                severity: InfoBarSeverity.info,
              ),
            );
          },
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.arrow_sync_24_regular),
          onPressed: () => ref.invalidate(invoicesListProvider),
        ),
      ],
      secondaryItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.print_24_regular),
          label: const Text('Print Selected'),
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  displayInfoBar(
                    context,
                    builder: (context, close) => const InfoBar(
                      title: Text('Tip'),
                      content: Text(
                        'Use the print button on each row for individual invoices.',
                      ),
                      severity: InfoBarSeverity.info,
                    ),
                  );
                },
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.delete_24_regular),
          label: const Text('Void Selected'),
          onPressed: _selectedIds.isEmpty ? null : () => _voidSelected(),
        ),
      ],
    );
  }

  Widget _buildFinancialDashboard(
    BuildContext context,
    FluentThemeData theme,
    AsyncValue<List<Invoice>> invoicesAsync,
  ) {
    return invoicesAsync.when(
      data: (invoices) {
        // Calculate financial metrics
        double totalOutstanding = 0;
        double overdueAmount = 0;
        double paidThisMonth = 0;
        int draftCount = 0;
        int sentCount = 0;
        int overdueCount = 0;

        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);

        for (final inv in invoices) {
          if (inv.status == 'draft') {
            draftCount++;
          } else if (inv.status == 'sent') {
            sentCount++;
            totalOutstanding += inv.totalAmount;
            if (inv.dueDate.isBefore(now)) {
              overdueAmount += inv.totalAmount;
              overdueCount++;
            }
          } else if (inv.status == 'overdue') {
            overdueCount++;
            overdueAmount += inv.totalAmount;
            totalOutstanding += inv.totalAmount;
          } else if (inv.status == 'paid') {
            if (inv.updatedAt != null && inv.updatedAt!.isAfter(monthStart)) {
              paidThisMonth += inv.totalAmount;
            }
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Outstanding
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Total Outstanding',
                  currencyFormat.format(totalOutstanding),
                  FluentIcons.money_24_regular,
                  Colors.blue,
                  subtitle: '${sentCount + overdueCount} invoices',
                ),
              ),
              const SizedBox(width: 16),
              // Overdue
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Overdue',
                  currencyFormat.format(overdueAmount),
                  FluentIcons.warning_24_regular,
                  Colors.red,
                  subtitle: '$overdueCount invoices',
                  isAlert: overdueAmount > 0,
                ),
              ),
              const SizedBox(width: 16),
              // Paid This Month
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Collected This Month',
                  currencyFormat.format(paidThisMonth),
                  FluentIcons.checkmark_circle_24_regular,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              // Drafts
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Pending Drafts',
                  draftCount.toString(),
                  FluentIcons.document_24_regular,
                  Colors.orange,
                  subtitle: 'Ready to send',
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: const Center(child: ProgressRing()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildMetricCard(
    FluentThemeData theme,
    String label,
    String value,
    IconData icon,
    AccentColor color, {
    String? subtitle,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAlert ? color : theme.resources.cardStrokeColorDefault,
          width: isAlert ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.typography.subtitle?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAlert ? color : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters(FluentThemeData theme) {
    final statuses = ['All', 'draft', 'sent', 'paid', 'overdue', 'void'];
    final labels = ['All', 'Drafts', 'Sent', 'Paid', 'Overdue', 'Voided'];

    return Row(
      children: List.generate(statuses.length, (index) {
        final isSelected = _statusFilter == statuses[index];
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
          child: ToggleButton(
            checked: isSelected,
            onChanged: (_) => setState(() {
              _statusFilter = statuses[index];
              _selectedIds.clear();
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(labels[index]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInvoiceTable(
    List<Invoice> invoices,
    FluentThemeData theme,
    ResourceDictionary resources,
  ) {
    // Filter by search
    var filtered = invoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return inv.invoiceNumber.toLowerCase().contains(query) ||
          (inv.customerId?.toLowerCase().contains(query) ?? false);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int result;
      switch (_sortColumn) {
        case 'number':
          result = a.invoiceNumber.compareTo(b.invoiceNumber);
        case 'date':
          result = a.issueDate.compareTo(b.issueDate);
        case 'due':
          result = a.dueDate.compareTo(b.dueDate);
        case 'amount':
          result = a.totalAmount.compareTo(b.totalAmount);
        case 'status':
          result = a.status.compareTo(b.status);
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });

    if (filtered.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      children: [
        // Header Row
        _buildHeaderRow(theme, resources),
        const Divider(),
        // Data Rows
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final invoice = filtered[index];
              final isSelected = _selectedIds.contains(invoice.id);
              final isEven = index % 2 == 0;
              final isOverdue =
                  invoice.status == 'sent' &&
                  invoice.dueDate.isBefore(DateTime.now());

              return _buildDataRow(
                context,
                theme,
                resources,
                invoice,
                isSelected,
                isEven,
                isOverdue,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(FluentThemeData theme, ResourceDictionary resources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: resources.subtleFillColorSecondary,
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              checked: _selectedIds.isNotEmpty,
              onChanged: (val) {},
            ),
          ),
          // Invoice #
          _buildSortableHeader(theme, 'Invoice #', 'number', flex: 2),
          // Date
          _buildSortableHeader(theme, 'Issue Date', 'date', flex: 2),
          // Due Date
          _buildSortableHeader(theme, 'Due Date', 'due', flex: 2),
          // Customer
          Expanded(
            flex: 3,
            child: Text('Customer', style: theme.typography.bodyStrong),
          ),
          // Amount
          _buildSortableHeader(theme, 'Amount', 'amount', flex: 2),
          // Status
          _buildSortableHeader(theme, 'Status', 'status', flex: 2),
          // Actions
          const SizedBox(width: 120),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(
    FluentThemeData theme,
    String label,
    String column, {
    int flex = 1,
  }) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortColumn == column) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = column;
              _sortAscending = true;
            }
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            children: [
              Text(
                label,
                style: theme.typography.bodyStrong?.copyWith(
                  color: isActive ? theme.accentColor : null,
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    _sortAscending
                        ? FluentIcons.arrow_up_24_regular
                        : FluentIcons.arrow_down_24_regular,
                    size: 12,
                    color: theme.accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    FluentThemeData theme,
    ResourceDictionary resources,
    Invoice invoice,
    bool isSelected,
    bool isEven,
    bool isOverdue,
  ) {
    final daysUntilDue = invoice.dueDate.difference(DateTime.now()).inDays;

    return HoverButton(
      onPressed: () {
        // Toggle selection on click
        setState(() {
          if (_selectedIds.contains(invoice.id)) {
            _selectedIds.remove(invoice.id);
          } else {
            _selectedIds.add(invoice.id);
          }
        });
      },
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.1)
                : isHovered
                ? resources.subtleFillColorSecondary
                : isEven
                ? resources.cardBackgroundFillColorDefault
                : resources.cardBackgroundFillColorSecondary,
            border: Border(
              bottom: BorderSide(
                color: resources.dividerStrokeColorDefault,
                width: 0.5,
              ),
              left: isOverdue
                  ? BorderSide(color: Colors.red, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 40,
                child: Checkbox(
                  checked: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(invoice.id);
                      } else {
                        _selectedIds.remove(invoice.id);
                      }
                    });
                  },
                ),
              ),
              // Invoice #
              Expanded(
                flex: 2,
                child: Text(
                  invoice.invoiceNumber,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Issue Date
              Expanded(
                flex: 2,
                child: Text(dateFormat.format(invoice.issueDate)),
              ),
              // Due Date
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dateFormat.format(invoice.dueDate)),
                    if (invoice.status != 'paid' && invoice.status != 'void')
                      Text(
                        isOverdue
                            ? '${-daysUntilDue} days overdue'
                            : daysUntilDue == 0
                            ? 'Due today'
                            : 'Due in $daysUntilDue days',
                        style: TextStyle(
                          fontSize: 10,
                          color: isOverdue
                              ? Colors.red
                              : daysUntilDue <= 7
                              ? Colors.orange
                              : theme.resources.textFillColorTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              // Customer
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      invoice.customerName ?? 'Unknown',
                      style: theme.typography.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (invoice.customerAddress != null)
                      Text(
                        invoice.customerAddress!,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Amount
              Expanded(
                flex: 2,
                child: Text(
                  currencyFormat.format(invoice.totalAmount),
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: _buildStatusChip(invoice.status, isOverdue),
              ),
              // Actions
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (invoice.status == 'draft')
                      IconButton(
                        icon: Icon(
                          FluentIcons.send_24_regular,
                          size: 16,
                          color: isHovered ? theme.accentColor : null,
                        ),
                        onPressed: () => _sendInvoice(invoice.id),
                      ),
                    if (invoice.status == 'sent' || invoice.status == 'overdue')
                      IconButton(
                        icon: Icon(
                          FluentIcons.checkmark_24_regular,
                          size: 16,
                          color: isHovered ? Colors.green : null,
                        ),
                        onPressed: () => _markPaid(invoice.id),
                      ),
                    IconButton(
                      icon: Icon(
                        FluentIcons.print_24_regular,
                        size: 16,
                        color: isHovered ? theme.accentColor : null,
                      ),
                      onPressed: () => _printInvoice(invoice),
                    ),
                    DropDownButton(
                      leading: const Icon(
                        FluentIcons.more_vertical_24_regular,
                        size: 16,
                      ),
                      items: [
                        MenuFlyoutItem(
                          leading: const Icon(FluentIcons.open_24_regular),
                          text: const Text('Open PDF'),
                          onPressed: () async {
                            final company = await ref.read(
                              companyProvider.future,
                            );
                            await InvoicePdfGenerator.printInvoice(
                              invoice,
                              company,
                            );
                          },
                        ),
                        const MenuFlyoutSeparator(),
                        MenuFlyoutItem(
                          leading: Icon(
                            FluentIcons.delete_24_regular,
                            color: Colors.red,
                          ),
                          text: Text(
                            'Void Invoice',
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: () => _voidInvoice(invoice),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status, bool isOverdue) {
    Color color;
    String label;

    switch (status) {
      case 'draft':
        color = Colors.blue;
        label = 'DRAFT';
      case 'sent':
        color = isOverdue ? Colors.red : Colors.orange;
        label = isOverdue ? 'OVERDUE' : 'SENT';
      case 'paid':
        color = Colors.green;
        label = 'PAID';
      case 'overdue':
        color = Colors.red;
        label = 'OVERDUE';
      case 'void':
        color = Colors.grey;
        label = 'VOID';
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.document_24_regular,
            size: 64,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _statusFilter == 'All'
                ? 'No invoices yet'
                : 'No $_statusFilter invoices',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first invoice to start billing customers.',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _showInvoiceBuilder(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add_24_regular, size: 16),
                SizedBox(width: 8),
                Text('Create Invoice'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(FluentThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.error_circle_24_regular,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text('Error loading invoices', style: theme.typography.subtitle),
          const SizedBox(height: 8),
          Text(error, style: theme.typography.caption),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(invoicesListProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceBuilder(BuildContext context) {
    // Invoice creation is typically done from the Loads page
    // This shows a guidance dialog
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Create Invoice'),
        content: const Text(
          'To create an invoice, go to the Loads page, find a delivered load, '
          'and click "Generate Invoice" from the load actions menu.',
        ),
        actions: [
          Button(
            child: const Text('Go to Loads'),
            onPressed: () {
              Navigator.pop(context);
              context.go('/highway-dispatch');
            },
          ),
          FilledButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkSend() async {
    if (_selectedIds.isEmpty) return;

    for (final id in _selectedIds) {
      await ref
          .read(invoiceControllerProvider.notifier)
          .updateStatus(id, 'sent');
    }

    setState(() => _selectedIds.clear());

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('${_selectedIds.length} invoice(s) sent'),
          severity: InfoBarSeverity.success,
        ),
      );
    }
  }

  Future<void> _sendInvoice(String invoiceId) async {
    await ref
        .read(invoiceControllerProvider.notifier)
        .updateStatus(invoiceId, 'sent');

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Invoice sent'),
          severity: InfoBarSeverity.success,
        ),
      );
    }
  }

  Future<void> _markPaid(String invoiceId) async {
    await ref
        .read(invoiceControllerProvider.notifier)
        .updateStatus(invoiceId, 'paid');

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Invoice marked as paid'),
          severity: InfoBarSeverity.success,
        ),
      );
    }
  }

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      final company = await ref.read(companyProvider.future);
      await InvoicePdfGenerator.printInvoice(invoice, company);
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Print failed'),
            content: Text('Error: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

  Future<void> _voidSelected() async {
    final count = _selectedIds.length;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Void Invoices'),
        content: Text(
          'Are you sure you want to void $count invoice(s)? '
          'This action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Void'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final id in _selectedIds.toList()) {
      await ref
          .read(invoiceControllerProvider.notifier)
          .updateStatus(id, 'void');
    }

    setState(() => _selectedIds.clear());

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('$count invoice(s) voided'),
          severity: InfoBarSeverity.warning,
        ),
      );
    }
  }

  Future<void> _voidInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Void Invoice'),
        content: Text(
          'Are you sure you want to void invoice ${invoice.invoiceNumber}? '
          'This action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Void'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(invoiceControllerProvider.notifier)
        .updateStatus(invoice.id, 'void');

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('Invoice ${invoice.invoiceNumber} voided'),
          severity: InfoBarSeverity.warning,
        ),
      );
    }
  }
}
