import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:terminal/features/drivers/presentation/providers/driver_selection_provider.dart';
import '../providers/settlement_providers.dart';
import '../widgets/generate_settlement_dialog.dart';

import '../../domain/models/driver_settlement.dart';
import '../../domain/models/settlement_summary.dart';

class SettlementsPage extends ConsumerStatefulWidget {
  const SettlementsPage({super.key});

  @override
  ConsumerState<SettlementsPage> createState() => _SettlementsPageState();
}

enum SettlementFilterStatus { all, draft, approved, paid, voided }

class _SettlementsPageState extends ConsumerState<SettlementsPage> {
  final currencyFormat = NumberFormat.currency(symbol: r'$');
  final dateFormat = DateFormat('MM/dd/yyyy');
  SettlementFilterStatus _filter = SettlementFilterStatus.all;
  final Set<String> _selectedIds = {};

  Future<void> _updateStatus(
    BuildContext context,
    DriverSettlement settlement,
    SettlementStatus status,
  ) async {
    final driverId = ref.read(selectedDriverProvider)?.id;
    if (driverId == null) return;

    await ref
        .read(settlementControllerProvider.notifier)
        .updateStatus(settlement.id, driverId, status);

    if (context.mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Status Updated'),
          content: Text('Settlement ${settlement.id} is now ${status.name}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _batchUpdateStatus(SettlementStatus status) async {
    final driverId = ref.read(selectedDriverProvider)?.id;
    if (driverId == null) return;

    final controller = ref.read(settlementControllerProvider.notifier);
    int count = 0;

    for (final id in _selectedIds) {
      await controller.updateStatus(id, driverId, status);
      count++;
    }

    if (mounted) {
      setState(() => _selectedIds.clear());
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('Batch Update Complete'),
          content: Text('Updated $count settlements to ${status.name}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  void _showNotImplemented(BuildContext context, String action) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text('$action Not Implemented'),
        content: const Text(
          'This feature will be available in a future update.',
        ),
        severity: InfoBarSeverity.warning,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDriver = ref.watch(selectedDriverProvider);

    if (selectedDriver == null) {
      return const ScaffoldPage(
        header: PageHeader(title: Text('Driver Settlements')),
        content: Center(
          child: Text('Select a driver from the sidebar to view settlements.'),
        ),
      );
    }

    final settlementsAsync = ref.watch(
      driverSettlementsProvider(selectedDriver.id),
    );
    final summaryAsync = ref.watch(
      fetchSettlementSummaryDataProvider(selectedDriver.id),
    );

    return ScaffoldPage(
      header: PageHeader(
        title: Text('Settlements: ${selectedDriver.fullName}'),
        commandBar: Button(
          onPressed: () =>
              _showGenerateSettlementDialog(context, selectedDriver.id),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add_24_regular, size: 16),
              SizedBox(width: 8),
              Text('Generate Settlement'),
            ],
          ),
        ),
      ),
      content: settlementsAsync.when(
        data: (settlements) {
          if (settlements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.receipt_24_regular,
                    size: 64,
                    color: FluentTheme.of(
                      context,
                    ).resources.textFillColorDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No settlements found',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete trips and fuel entries to generate your first settlement.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _showGenerateSettlementDialog(
                      context,
                      selectedDriver.id,
                    ),
                    child: const Text('Generate Settlement'),
                  ),
                ],
              ),
            );
          }

          final filteredSettlements = settlements.where((s) {
            if (_filter == SettlementFilterStatus.all) return true;
            return s.status.name == _filter.name;
          }).toList();

          if (filteredSettlements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No settlements matching the filter.'),
                  const SizedBox(height: 16),
                  Button(
                    onPressed: () =>
                        setState(() => _filter = SettlementFilterStatus.all),
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            );
          }

          return summaryAsync.when(
            data: (summary) => Stack(
              children: [
                Column(
                  children: [
                    // Summary Cards
                    _buildSummaryRow(summary),
                    const SizedBox(height: 24),

                    // Filter Bar
                    _buildFilterBar(),
                    const SizedBox(height: 16),

                    // Data Table
                    _buildDataTableHeader(filteredSettlements),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filteredSettlements.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final s = filteredSettlements[index];
                          return _SettlementRowItem(
                            settlement: s,
                            isSelected: _selectedIds.contains(s.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedIds.add(s.id);
                                } else {
                                  _selectedIds.remove(s.id);
                                }
                              });
                            },
                            onUpdateStatus: (status) =>
                                _updateStatus(context, s, status),
                            onAction: (action) =>
                                _showNotImplemented(context, action),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_selectedIds.isNotEmpty)
                  _buildBatchCommandBar(filteredSettlements),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, s) =>
                Center(child: Text('Error calculating summary: $e')),
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, s) => Center(child: Text('Error loading settlements: $e')),
      ),
    );
  }

  Widget _buildSummaryRow(SettlementSummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _StatsCard(
              title: 'Total Pending',
              amount: currencyFormat.format(summary.totalPending),
              icon: FluentIcons.clock_24_regular,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsCard(
              title: 'Total Paid',
              amount: currencyFormat.format(summary.totalPaid),
              icon: FluentIcons.checkmark_circle_24_regular,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsCard(
              title: 'Avg. Payout',
              amount: currencyFormat.format(summary.averagePayout),
              icon: FluentIcons.calculator_24_regular,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsCard(
              title: 'Unsettled Items',
              amount: summary.unsettledItemsCount.toString(),
              icon: FluentIcons.warning_24_regular,
              color: summary.unsettledItemsCount > 0 ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ...SettlementFilterStatus.values.map((f) {
            final isSelected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Button(
                style: ButtonStyle(
                  backgroundColor: isSelected
                      ? WidgetStateProperty.all(
                          FluentTheme.of(
                            context,
                          ).accentColor.withValues(alpha: 0.1),
                        )
                      : null,
                  shape: isSelected
                      ? WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            side: BorderSide(
                              color: FluentTheme.of(context).accentColor,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      : null,
                ),
                onPressed: () => setState(() => _filter = f),
                child: Text(
                  f.name[0].toUpperCase() + f.name.substring(1),
                  style: TextStyle(
                    color: isSelected
                        ? FluentTheme.of(context).accentColor
                        : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataTableHeader(List<DriverSettlement> settlements) {
    final allInFilterSelected = settlements.every(
      (s) => _selectedIds.contains(s.id),
    );
    final someInFilterSelected = settlements.any(
      (s) => _selectedIds.contains(s.id),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.subtleFillColorSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              checked: allInFilterSelected
                  ? true
                  : (someInFilterSelected ? null : false),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    for (final s in settlements) {
                      _selectedIds.add(s.id);
                    }
                  } else {
                    for (final s in settlements) {
                      _selectedIds.remove(s.id);
                    }
                  }
                });
              },
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Settlement ID',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Period',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Net Payout',
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 48), // Space for chevron
        ],
      ),
    );
  }

  Widget _buildBatchCommandBar(List<DriverSettlement> filteredSettlements) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Card(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              '${_selectedIds.length} items selected',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            CommandBar(
              primaryItems: [
                CommandBarButton(
                  icon: const Icon(FluentIcons.checkmark_24_regular),
                  label: const Text('Approve'),
                  onPressed: () =>
                      _batchUpdateStatus(SettlementStatus.approved),
                ),
                CommandBarButton(
                  icon: const Icon(FluentIcons.money_24_regular),
                  label: const Text('Mark as Paid'),
                  onPressed: () => _batchUpdateStatus(SettlementStatus.paid),
                ),
                CommandBarButton(
                  icon: const Icon(FluentIcons.error_circle_24_regular),
                  label: const Text('Void'),
                  onPressed: () => _batchUpdateStatus(SettlementStatus.voided),
                ),
              ],
              secondaryItems: [
                CommandBarButton(
                  icon: const Icon(FluentIcons.print_24_regular),
                  label: const Text('Print Batch'),
                  onPressed: () => _showNotImplemented(context, 'Print Batch'),
                ),
                CommandBarButton(
                  icon: const Icon(FluentIcons.arrow_export_up_24_regular),
                  label: const Text('Export CSV'),
                  onPressed: () => _showNotImplemented(context, 'Export CSV'),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              onPressed: () => setState(() => _selectedIds.clear()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGenerateSettlementDialog(
    BuildContext context,
    String driverId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => GenerateSettlementDialog(driverId: driverId),
    );
  }
}

class _SettlementRowItem extends StatefulWidget {
  final DriverSettlement settlement;
  final bool isSelected;
  final ValueChanged<bool?> onSelected;
  final Function(SettlementStatus) onUpdateStatus;
  final Function(String) onAction;

  const _SettlementRowItem({
    required this.settlement,
    required this.isSelected,
    required this.onSelected,
    required this.onUpdateStatus,
    required this.onAction,
  });

  @override
  State<_SettlementRowItem> createState() => _SettlementRowItemState();
}

class _SettlementRowItemState extends State<_SettlementRowItem> {
  final FlyoutController _flyoutController = FlyoutController();
  Offset _targetPosition = Offset.zero;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showContextMenu() {
    _flyoutController.showFlyout(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.eye_24_regular),
              text: const Text('View Details'),
              onPressed: () {
                Navigator.pop(context);
                context.go('/settlements/details/${widget.settlement.id}');
              },
            ),
            if (widget.settlement.status == SettlementStatus.draft)
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.checkmark_24_regular),
                text: const Text('Approve'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onUpdateStatus(SettlementStatus.approved);
                },
              ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.print_24_regular),
              text: const Text('Print'),
              onPressed: () {
                Navigator.pop(context);
                widget.onAction('Print');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final currencyFormat = NumberFormat.currency(symbol: r'$');
    final dateFormat = DateFormat('MM/dd/yyyy');

    return GestureDetector(
      onSecondaryTapUp: (details) {
        setState(() {
          _targetPosition = details.localPosition;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showContextMenu();
        });
      },
      child: Stack(
        children: [
          Focus(
            onKeyEvent: (node, event) {
              return KeyEventResult.ignored;
            },
            child: HoverButton(
              onPressed: () => context.go('/settlements/details/${s.id}'),
              builder: (context, states) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  color: widget.isSelected
                      ? FluentTheme.of(
                          context,
                        ).accentColor.withValues(alpha: 0.1)
                      : states.isHovered
                      ? FluentTheme.of(
                          context,
                        ).resources.subtleFillColorSecondary
                      : Colors.transparent,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Checkbox(
                          checked: widget.isSelected,
                          onChanged: widget.onSelected,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.id.substring(0, 8).toUpperCase(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${dateFormat.format(s.startDate)} - ${dateFormat.format(s.endDate)}',
                        ),
                      ),
                      Expanded(flex: 2, child: _StatusBadge(status: s.status)),
                      Expanded(
                        flex: 2,
                        child: Text(
                          currencyFormat.format(s.netPayout),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.netPayout >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                        child: Icon(
                          FluentIcons.chevron_right_24_regular,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: _targetPosition.dx,
            top: _targetPosition.dy,
            child: FlyoutTarget(
              controller: _flyoutController,
              child: const SizedBox(height: 1, width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(title, style: FluentTheme.of(context).typography.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: FluentTheme.of(
              context,
            ).typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SettlementStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case SettlementStatus.draft:
        color = Colors.orange;
        break;
      case SettlementStatus.approved:
        color = Colors.blue;
        break;
      case SettlementStatus.paid:
        color = Colors.green;
        break;
      case SettlementStatus.voided:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
