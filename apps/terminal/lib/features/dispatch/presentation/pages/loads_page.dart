import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../providers/load_providers.dart';
import '../../domain/models/load.dart';
import '../widgets/load_entry_form.dart';
import '../widgets/broker_entry_dialog.dart';
import '../../domain/models/broker.dart';
import 'package:intl/intl.dart';

class LoadsPage extends ConsumerStatefulWidget {
  const LoadsPage({super.key});

  @override
  ConsumerState<LoadsPage> createState() => _LoadsPageState();
}

class _LoadsPageState extends ConsumerState<LoadsPage> {
  final List<Load> _loads = [];
  final List<Broker> _brokers = [
    Broker.empty().copyWith(name: 'TQL'),
    Broker.empty().copyWith(name: 'CH Robinson'),
    Broker.empty().copyWith(name: 'Cowan'),
  ];
  late LoadDataSource _loadDataSource;

  @override
  void initState() {
    super.initState();
    _loadDataSource = LoadDataSource(loads: _loads);
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingLoad = ref.watch(isCreatingLoadProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: isCreatingLoad
          ? null
          : PageHeader(
              title: const Text('Dispatch Board'),
              commandBar: CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add_24_regular),
                    label: const Text('New Load'),
                    onPressed: () =>
                        ref.read(isCreatingLoadProvider.notifier).toggle(true),
                  ),
                  CommandBarButton(
                    icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
                    label: const Text('Refresh'),
                    onPressed: () {
                      _loadDataSource.notifyListeners();
                    },
                  ),
                ],
                secondaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.person_add_24_regular),
                    label: const Text('New Broker'),
                    onPressed: _openNewBrokerDialog,
                  ),
                ],
              ),
            ),
      content: isCreatingLoad
          ? LoadEntryForm(
              brokers: _brokers,
              onAddBroker: _openNewBrokerDialog,
              onSave: (newLoad) async {
                await Future.delayed(const Duration(seconds: 1));
                setState(() {
                  _loads.add(newLoad);
                  _loadDataSource.updateDataGridSource();
                });
                ref.read(isCreatingLoadProvider.notifier).toggle(false);
                ref.read(loadDraftProvider.notifier).reset();
              },
              onCancel: () {
                ref.read(isCreatingLoadProvider.notifier).toggle(false);
                ref.read(loadDraftProvider.notifier).reset();
              },
            )
          : _loads.isEmpty
          ? _buildEmptyState()
          : SfDataGridTheme(
              data: SfDataGridThemeData(
                headerColor: theme.resources.surfaceStrokeColorDefault,
                gridLineColor: theme.resources.surfaceStrokeColorDefault,
                gridLineStrokeWidth: 1.0,
              ),
              child: SfDataGrid(
                source: _loadDataSource,
                columnWidthMode: ColumnWidthMode.fill,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                columns: <GridColumn>[
                  GridColumn(
                    columnName: 'reference',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerLeft,
                      child: const Text('Reference'),
                    ),
                  ),
                  GridColumn(
                    columnName: 'broker',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerLeft,
                      child: const Text('Broker'),
                    ),
                  ),
                  GridColumn(
                    columnName: 'rate',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerRight,
                      child: const Text('Rate'),
                    ),
                  ),
                  GridColumn(
                    columnName: 'pickup',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerLeft,
                      child: const Text('Pickup'),
                    ),
                  ),
                  GridColumn(
                    columnName: 'delivery',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerLeft,
                      child: const Text('Delivery'),
                    ),
                  ),
                  GridColumn(
                    columnName: 'status',
                    label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.centerLeft,
                      child: const Text('Status'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.vehicle_truck_profile_24_regular, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No active loads',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Click "New Load" to add a shipment from the board.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                ref.read(isCreatingLoadProvider.notifier).toggle(true),
            child: const Text('Add First Load'),
          ),
        ],
      ),
    );
  }

  Future<Broker?> _openNewBrokerDialog() async {
    Broker? createdBroker;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return BrokerEntryDialog(
          onSave: (newBroker) async {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            setState(() {
              _brokers.add(newBroker);
            });
            createdBroker = newBroker;
            if (!mounted) return;
            displayInfoBar(
              alignment: Alignment.bottomRight,
              context,
              builder: (infoBarContext, close) {
                return InfoBar(
                  title: const Text('Broker Saved'),
                  content: Text('Saved ${newBroker.name}'),
                  severity: InfoBarSeverity.success,
                  onClose: close,
                  action: IconButton(
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    onPressed: close,
                  ),
                );
              },
            );
          },
        );
      },
    );
    return createdBroker;
  }
}

class LoadDataSource extends DataGridSource {
  LoadDataSource({required List<Load> loads}) {
    _loads = loads;
    _buildDataGridRows();
  }

  List<Load> _loads = [];
  List<DataGridRow> _dataGridRows = [];

  void _buildDataGridRows() {
    _dataGridRows = _loads.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'reference', value: e.loadReference),
          DataGridCell<String>(columnName: 'broker', value: e.brokerName),
          DataGridCell<String>(
            columnName: 'rate',
            value:
                '${NumberFormat.currency(symbol: '\$').format(e.rate)} ${e.currency}',
          ),
          DataGridCell<String>(
            columnName: 'pickup',
            value: '${e.pickup.city}, ${e.pickup.state}',
          ),
          DataGridCell<String>(
            columnName: 'delivery',
            value: '${e.delivery.city}, ${e.delivery.state}',
          ),
          DataGridCell<String>(columnName: 'status', value: e.status),
        ],
      );
    }).toList();
  }

  void updateDataGridSource() {
    _buildDataGridRows();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((e) {
        return Container(
          alignment: e.columnName == 'rate'
              ? Alignment.centerRight
              : Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: Text(e.value.toString()),
        );
      }).toList(),
    );
  }
}
