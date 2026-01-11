import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/driver_pay_config.dart';
import '../../domain/models/settlement_item.dart';
import '../providers/settlement_providers.dart';

class GenerateSettlementDialog extends ConsumerStatefulWidget {
  final String driverId;

  const GenerateSettlementDialog({super.key, required this.driverId});

  @override
  ConsumerState<GenerateSettlementDialog> createState() =>
      _GenerateSettlementDialogState();
}

class _GenerateSettlementDialogState
    extends ConsumerState<GenerateSettlementDialog> {
  final currencyFormat = NumberFormat.currency(symbol: r'$');
  final List<String> _selectedLoadIds = [];
  final List<String> _selectedFuelIds = [];

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final payConfigAsync = ref.watch(driverPayConfigProvider(widget.driverId));
    final loadsAsync = ref.watch(unsettledLoadsProvider(widget.driverId));
    final fuelAsync = ref.watch(unsettledFuelProvider(widget.driverId));

    return ContentDialog(
      title: const Text('Generate Settlement'),
      constraints: const BoxConstraints(maxWidth: 800),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range
            const Text(
              'Period Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DatePicker(
                    header: 'Start Date',
                    selected: _startDate,
                    onChanged: (date) => setState(() => _startDate = date),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DatePicker(
                    header: 'End Date',
                    selected: _endDate,
                    onChanged: (date) => setState(() => _endDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pay Config Warning
            payConfigAsync.when(
              data: (config) {
                if (config == null) {
                  return InfoBar(
                    title: const Text('Missing Pay Setup'),
                    content: const Text(
                      'This driver has no pay configuration. Defaulting to 0% percentage pay.',
                    ),
                    severity: InfoBarSeverity.warning,
                  );
                }
                return Text(
                  'Active Pay Model: ${config.payType.name.toUpperCase()} (${config.payType == DriverPayType.cpm ? currencyFormat.format(config.payValue) : '${config.payValue}%'})',
                );
              },
              loading: () => const ProgressRing(),
              error: (e, s) => Text('Error loading config: $e'),
            ),
            const SizedBox(height: 24),

            // Loads
            const Text(
              'Unsettled Loads',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            loadsAsync.when(
              data: (loads) {
                if (loads.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No new delivered loads found.'),
                  );
                }
                return Column(
                  children: loads.map((load) {
                    final isSelected = _selectedLoadIds.contains(load['id']);
                    return ListTile(
                      title: Text(
                        'Trip #${load['trip_number']} - ${load['load_reference'] ?? 'No Ref'}',
                      ),
                      subtitle: Text(
                        'Rate: ${currencyFormat.format(load['rate'])}',
                      ),
                      leading: Checkbox(
                        checked: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLoadIds.add(load['id']);
                            } else {
                              _selectedLoadIds.remove(load['id']);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const ProgressRing(),
              error: (e, s) => Text('Error: $e'),
            ),

            const SizedBox(height: 24),
            // Fuel
            const Text(
              'Unsettled Fuel Deductions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            fuelAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No new fuel entries found.'),
                  );
                }
                return Column(
                  children: entries.map((fuel) {
                    final isSelected = _selectedFuelIds.contains(fuel['id']);
                    return ListTile(
                      title: Text(
                        '${fuel['truck_number']} - ${fuel['location']}',
                      ),
                      subtitle: Text(
                        'Cost: ${currencyFormat.format(fuel['total_cost'])}',
                      ),
                      leading: Checkbox(
                        checked: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedFuelIds.add(fuel['id']);
                            } else {
                              _selectedFuelIds.remove(fuel['id']);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const ProgressRing(),
              error: (e, s) => Text('Error: $e'),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: (_selectedLoadIds.isEmpty && _selectedFuelIds.isEmpty)
              ? null
              : () => _handleGenerate(payConfigAsync.value),
          child: const Text('Generate Draft'),
        ),
      ],
    );
  }

  Future<void> _handleGenerate(DriverPayConfig? config) async {
    final loads = ref.read(unsettledLoadsProvider(widget.driverId)).value ?? [];
    final fuel = ref.read(unsettledFuelProvider(widget.driverId)).value ?? [];

    final items = <SettlementItem>[];

    // Add Loads
    for (final loadId in _selectedLoadIds) {
      final load = loads.firstWhere((l) => l['id'] == loadId);
      double amount = 0;
      if (config != null) {
        if (config.payType == DriverPayType.percentage) {
          amount = (load['rate'] as num).toDouble() * (config.payValue / 100);
        } else if (config.payType == DriverPayType.flat) {
          amount = config.payValue;
        }
        // CPM logic would require miles from trip
      }

      items.add(
        SettlementItem(
          id: '',
          settlementId: '',
          type: SettlementItemType.loadPay,
          description: 'Load Pay: Trip #${load['trip_number']}',
          amount: amount,
          referenceId: loadId,
        ),
      );
    }

    // Add Fuel Deductions
    for (final fuelId in _selectedFuelIds) {
      final entry = fuel.firstWhere((f) => f['id'] == fuelId);
      items.add(
        SettlementItem(
          id: '',
          settlementId: '',
          type: SettlementItemType.fuelDeduction,
          description: 'Fuel Deduction: ${entry['location']}',
          amount: -(entry['total_cost'] as num).toDouble(),
          referenceId: fuelId,
        ),
      );
    }

    await ref
        .read(settlementControllerProvider.notifier)
        .createSettlement(
          driverId: widget.driverId,
          startDate: _startDate,
          endDate: _endDate,
          items: items,
        );

    if (mounted) Navigator.pop(context);
  }
}
