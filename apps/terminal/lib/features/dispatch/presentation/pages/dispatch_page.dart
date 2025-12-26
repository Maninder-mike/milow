import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/load_providers.dart';
import '../../domain/models/load.dart';
import '../widgets/load_entry_form.dart';
import '../widgets/broker_entry_dialog.dart';
import '../../domain/models/broker.dart';

class DispatchPage extends ConsumerStatefulWidget {
  const DispatchPage({super.key});

  @override
  ConsumerState<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends ConsumerState<DispatchPage> {
  final List<Load> _loads = [];
  final List<Broker> _brokers = [
    Broker.empty().copyWith(name: 'TQL'),
    Broker.empty().copyWith(name: 'CH Robinson'),
    Broker.empty().copyWith(name: 'Cowan'),
  ];

  @override
  Widget build(BuildContext context) {
    final isCreatingLoad = ref.watch(isCreatingLoadProvider);

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
                    onPressed: () {},
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
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _loads.length,
              itemBuilder: (context, index) {
                final load = _loads[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(FluentIcons.clock_24_regular),
                      title: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(
                              text: load.brokerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' - #${load.loadReference}',
                              style: TextStyle(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            const TextSpan(text: '  |  '),
                            TextSpan(
                              text: 'PU: ',
                              style: TextStyle(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: '${load.pickup.city}, ${load.pickup.state}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const TextSpan(text: ' -> '),
                            TextSpan(
                              text: 'DEL: ',
                              style: TextStyle(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '${load.delivery.city}, ${load.delivery.state}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Text(
                        'Goods: ${load.goods}  |  Rate: \$${load.rate.toStringAsFixed(2)} ${load.currency}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x30808080),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(load.status),
                      ),
                    ),
                  ),
                );
              },
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
