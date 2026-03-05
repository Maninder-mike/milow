import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/models/driver_settlement.dart';
import '../providers/settlement_providers.dart';

class SettlementDataTable extends ConsumerStatefulWidget {
  final List<DriverSettlement> settlements;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const SettlementDataTable({
    super.key,
    required this.settlements,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  ConsumerState<SettlementDataTable> createState() =>
      _SettlementDataTableState();
}

class _SettlementDataTableState extends ConsumerState<SettlementDataTable> {
  final currencyFormat = NumberFormat.currency(symbol: r'$');
  final dateFormat = DateFormat('MMM d');

  bool get _allSelected {
    if (widget.settlements.isEmpty) return false;
    return widget.selectedIds.length == widget.settlements.length;
  }

  void _toggleAll(bool? checked) {
    if (checked == true) {
      widget.onSelectionChanged(widget.settlements.map((s) => s.id).toSet());
    } else {
      widget.onSelectionChanged({});
    }
  }

  void _toggleItem(String id, bool? checked) {
    final newSelection = Set<String>.from(widget.selectedIds);
    if (checked == true) {
      newSelection.add(id);
    } else {
      newSelection.remove(id);
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settlements.isEmpty) {
      return _buildEmptyState();
    }

    final theme = FluentTheme.of(context);
    final borderColor = theme.resources.controlStrokeColorDefault;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(theme),
          Expanded(
            child: ListView.builder(
              itemCount: widget.settlements.length,
              itemBuilder: (context, index) {
                final settlement = widget.settlements[index];
                final isSelected = widget.selectedIds.contains(settlement.id);
                final isEven = index % 2 == 0;
                return _buildRow(
                  context,
                  settlement,
                  isSelected,
                  isEven,
                  theme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.search_and_apps,
            size: 48,
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No settlements found',
            style: TextStyle(
              fontSize: 18,
              color: FluentTheme.of(context).resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.resources.controlStrokeColorDefault.withValues(
              alpha: 0.5,
            ),
          ),
        ),
      ),
      // Use Row for strict widths where necessary, Expanded for the rest
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(checked: _allSelected, onChanged: _toggleAll),
          ),
          SizedBox(width: 140, child: _buildHeaderCell('Settlement ID')),
          SizedBox(width: 160, child: _buildHeaderCell('Period')),
          SizedBox(width: 100, child: _buildHeaderCell('Status')),
          Expanded(
            child: _buildHeaderCell(
              'Gross',
              alignTarget: Alignment.centerRight,
            ),
          ),
          Expanded(
            child: _buildHeaderCell(
              'Deductions',
              alignTarget: Alignment.centerRight,
            ),
          ),
          Expanded(
            child: _buildHeaderCell(
              'Net Payout',
              alignTarget: Alignment.centerRight,
            ),
          ),
          const SizedBox(width: 32), // Chevron column
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String text, {
    Alignment alignTarget = Alignment.centerLeft,
  }) {
    return Container(
      alignment: alignTarget,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: FluentTheme.of(context).resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    DriverSettlement settlement,
    bool isSelected,
    bool isEven,
    FluentThemeData theme,
  ) {
    final bgColor = isSelected
        ? theme.accentColor.withValues(alpha: 0.1)
        : (isEven
              ? theme.scaffoldBackgroundColor.withValues(alpha: 0.3)
              : Colors.transparent);

    final String period =
        '${dateFormat.format(settlement.startDate)} - ${dateFormat.format(settlement.endDate)}';

    // Fallback if ID is too long (Supabase UUIDs)
    final shortId = settlement.id.length > 8
        ? settlement.id.substring(0, 8).toUpperCase()
        : settlement.id.toUpperCase();

    final controller = FlyoutController();

    return FlyoutTarget(
      controller: controller,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          controller.showFlyout(
            position: details.globalPosition,
            builder: (context) => _buildContextMenu(context, settlement),
          );
        },
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Checkbox(
                  checked: isSelected,
                  onChanged: (v) => _toggleItem(settlement.id, v),
                ),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  shortId,
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
              SizedBox(width: 160, child: Text(period)),
              SizedBox(width: 100, child: _buildStatusBadge(settlement.status)),
              Expanded(
                child: Text(
                  currencyFormat.format(settlement.totalEarnings),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  currencyFormat.format(settlement.totalDeductions),
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  currencyFormat.format(settlement.netPayout),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  icon: const Icon(FluentIcons.chevron_right, size: 12),
                  onPressed: () {
                    // Logic to open settlement details pane
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SettlementStatus status) {
    Color color;
    switch (status) {
      case SettlementStatus.draft:
        color = Colors.grey;
        break;
      case SettlementStatus.approved:
        color = Colors.blue;
        break;
      case SettlementStatus.paid:
        color = Colors.green;
        break;
      case SettlementStatus.voided:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.name.substring(0, 1).toUpperCase() + status.name.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context, DriverSettlement settlement) {
    return MenuFlyout(
      items: [
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.view),
          text: const Text('View Details'),
          onPressed: () {
            Navigator.pop(context); // Close menu
          },
        ),
        const MenuFlyoutSeparator(),
        if (settlement.status == SettlementStatus.draft)
          MenuFlyoutItem(
            leading: Icon(FluentIcons.check_mark, color: Colors.blue),
            text: const Text('Approve'),
            onPressed: () {
              ref
                  .read(settlementControllerProvider.notifier)
                  .updateStatus(
                    settlement.id,
                    settlement.driverId,
                    SettlementStatus.approved,
                  );
              Navigator.pop(context);
            },
          ),
        if (settlement.status == SettlementStatus.approved)
          MenuFlyoutItem(
            leading: Icon(FluentIcons.money, color: Colors.green),
            text: const Text('Mark Paid'),
            onPressed: () {
              ref
                  .read(settlementControllerProvider.notifier)
                  .updateStatus(
                    settlement.id,
                    settlement.driverId,
                    SettlementStatus.paid,
                  );
              Navigator.pop(context);
            },
          ),
        if (settlement.status != SettlementStatus.voided &&
            settlement.status != SettlementStatus.paid)
          MenuFlyoutItem(
            leading: Icon(FluentIcons.cancel, color: Colors.red),
            text: const Text('Void'),
            onPressed: () {
              ref
                  .read(settlementControllerProvider.notifier)
                  .updateStatus(
                    settlement.id,
                    settlement.driverId,
                    SettlementStatus.voided,
                  );
              Navigator.pop(context);
            },
          ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.print),
          text: const Text('Print Statement'),
          onPressed: () => Navigator.pop(context),
        ),
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.download),
          text: const Text('Export PDF'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
