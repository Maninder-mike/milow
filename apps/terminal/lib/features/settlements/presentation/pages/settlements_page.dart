import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:terminal/features/drivers/presentation/providers/driver_selection_provider.dart';
import '../providers/settlement_providers.dart';
import '../widgets/generate_settlement_dialog.dart';
import '../widgets/driver_selector_combo.dart';
import '../widgets/settlement_kpi_cards.dart';
import '../widgets/settlement_data_table.dart';

import '../../domain/models/driver_settlement.dart';

class SettlementsPage extends ConsumerStatefulWidget {
  const SettlementsPage({super.key});

  @override
  ConsumerState<SettlementsPage> createState() => _SettlementsPageState();
}

enum SettlementFilterStatus { all, draft, approved, paid, voided }

class _SettlementsPageState extends ConsumerState<SettlementsPage> {
  SettlementFilterStatus _filter = SettlementFilterStatus.all;
  Set<String> _selectedIds = {};
  String _searchQuery = '';

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
          title: const Text('Batch Update Complete'),
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

  Future<void> _showGenerateSettlementDialog(
    BuildContext context,
    String driverId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => GenerateSettlementDialog(driverId: driverId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDriver = ref.watch(selectedDriverProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            const Text('Settlements'),
            const SizedBox(width: 16),
            const DriverSelectorCombo(),
          ],
        ),
        commandBar: selectedDriver != null
            ? CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.checkmark_24_regular,
                      color: Colors.blue,
                    ),
                    label: const Text('Approve'),
                    onPressed: () =>
                        _batchUpdateStatus(SettlementStatus.approved),
                  ),
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.money_24_regular,
                      color: Colors.green,
                    ),
                    label: const Text('Mark as Paid'),
                    onPressed: () => _batchUpdateStatus(SettlementStatus.paid),
                  ),
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.error_circle_24_regular,
                      color: Colors.red,
                    ),
                    label: const Text('Void'),
                    onPressed: () =>
                        _batchUpdateStatus(SettlementStatus.voided),
                  ),
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add_24_regular),
                    label: const Text('Generate Settlement'),
                    onPressed: () => _showGenerateSettlementDialog(
                      context,
                      selectedDriver.id,
                    ),
                  ),
                  CommandBarButton(
                    icon: const Icon(FluentIcons.arrow_export_up_24_regular),
                    label: const Text('Export'),
                    onPressed: () => _showNotImplemented(context, 'Export'),
                  ),
                ],
              )
            : null,
      ),
      content: selectedDriver == null
          ? _buildNoDriverState()
          : _buildDriverContent(selectedDriver.id),
    );
  }

  Widget _buildNoDriverState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.person_24_regular,
            size: 64,
            color: FluentTheme.of(context).resources.textFillColorDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a Driver',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a driver from the dropdown above to view their settlements.',
          ),
        ],
      ),
    );
  }

  Widget _buildDriverContent(String driverId) {
    final settlementsAsync = ref.watch(driverSettlementsProvider(driverId));
    final summaryAsync = ref.watch(
      fetchSettlementSummaryDataProvider(driverId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI Summary section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: summaryAsync.when(
            data: (summary) => SettlementKPICards(summary: summary),
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: ProgressRing()),
            ),
            error: (e, s) => SizedBox(
              height: 120,
              child: Center(child: Text('Error loading summary: $e')),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: 16),

        // Data table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: settlementsAsync.when(
              data: (settlements) {
                final filteredByStatus = settlements.where((s) {
                  if (_filter == SettlementFilterStatus.all) return true;
                  return s.status.name == _filter.name;
                });

                final filteredSettlements = _searchQuery.isEmpty
                    ? filteredByStatus.toList()
                    : filteredByStatus
                          .where(
                            (s) => s.id.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                return Stack(
                  children: [
                    SettlementDataTable(
                      settlements: filteredSettlements,
                      selectedIds: _selectedIds,
                      onSelectionChanged: (ids) {
                        setState(() {
                          _selectedIds = ids;
                        });
                      },
                    ),
                    if (_selectedIds.isNotEmpty) _buildFloatingBatchActionBar(),
                  ],
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, s) =>
                  Center(child: Text('Error loading settlements: $e')),
            ),
          ),
        ),
        // Add some bottom padding so the table isn't flush against the window edge
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
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
                          borderRadius: BorderRadius.circular(24), // pill shape
                        ),
                      )
                    : WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
              ),
              onPressed: () {
                setState(() {
                  _filter = f;
                  _selectedIds.clear(); // Clear selection when filter changes
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  f.name[0].toUpperCase() + f.name.substring(1),
                  style: TextStyle(
                    color: isSelected
                        ? FluentTheme.of(context).accentColor
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        SizedBox(
          width: 250,
          child: TextBox(
            placeholder: 'Search settlements...',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(FluentIcons.search_24_regular),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBatchActionBar() {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: FluentTheme.of(
                context,
              ).resources.controlStrokeColorDefault,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedIds.length} items selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 24),
              CommandBar(
                isCompact: true,
                mainAxisAlignment: MainAxisAlignment.center,
                primaryItems: [
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.checkmark_24_regular,
                      color: Colors.blue,
                    ),
                    label: const Text('Approve'),
                    onPressed: () =>
                        _batchUpdateStatus(SettlementStatus.approved),
                  ),
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.money_24_regular,
                      color: Colors.green,
                    ),
                    label: const Text('Mark Paid'),
                    onPressed: () => _batchUpdateStatus(SettlementStatus.paid),
                  ),
                  CommandBarButton(
                    icon: Icon(
                      FluentIcons.error_circle_24_regular,
                      color: Colors.red,
                    ),
                    label: const Text('Void'),
                    onPressed: () =>
                        _batchUpdateStatus(SettlementStatus.voided),
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
      ),
    );
  }
}
