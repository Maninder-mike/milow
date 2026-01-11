import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:terminal/features/drivers/presentation/providers/driver_selection_provider.dart';
import '../providers/settlement_providers.dart';

class SettlementsPage extends ConsumerStatefulWidget {
  const SettlementsPage({super.key});

  @override
  ConsumerState<SettlementsPage> createState() => _SettlementsPageState();
}

class _SettlementsPageState extends ConsumerState<SettlementsPage> {
  final currencyFormat = NumberFormat.currency(symbol: r'$');
  final dateFormat = DateFormat('MM/dd/yyyy');

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

    return ScaffoldPage(
      header: PageHeader(
        title: Text('Settlements: ${selectedDriver.fullName}'),
        commandBar: Button(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add_24_regular, size: 16),
              SizedBox(width: 8),
              Text('Generate Settlement'),
            ],
          ),
          onPressed: () =>
              _showGenerateSettlementDialog(context, selectedDriver.id),
        ),
      ),
      content: settlementsAsync.when(
        data: (settlements) {
          if (settlements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No settlements found for this driver.'),
                  const SizedBox(height: 16),
                  Button(
                    child: const Text('Generate First Settlement'),
                    onPressed: () => _showGenerateSettlementDialog(
                      context,
                      selectedDriver.id,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: settlements.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final s = settlements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    'Period: ${dateFormat.format(s.startDate)} - ${dateFormat.format(s.endDate)}',
                  ),
                  subtitle: Text('Status: ${s.status.name.toUpperCase()}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(s.netPayout),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(
                        FluentIcons.chevron_right_24_regular,
                        size: 16,
                      ),
                    ],
                  ),
                  onPressed: () {
                    // TODO: Navigate to details
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showGenerateSettlementDialog(BuildContext context, String driverId) {
    // TODO: Implement settlement generation wizard
  }
}
