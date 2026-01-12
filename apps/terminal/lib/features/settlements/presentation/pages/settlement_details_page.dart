import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/settlement_item.dart';
import '../providers/settlement_providers.dart';

class SettlementDetailsPage extends ConsumerWidget {
  final String settlementId;

  const SettlementDetailsPage({super.key, required this.settlementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: r'$');
    final dateFormat = DateFormat('MM/dd/yyyy');
    final settlementAsync = ref.watch(settlementDetailsProvider(settlementId));

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Settlement Details'),
        commandBar: CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.print_24_regular),
              label: const Text('Print'),
              onPressed: () {},
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.send_24_regular),
              label: const Text('Email'),
              onPressed: () {},
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.arrow_download_24_regular),
              label: const Text('Export PDF'),
              onPressed: () {},
            ),
          ],
        ),
      ),
      content: settlementAsync.when(
        data: (settlement) {
          final items = settlement.items;
          final loads = items
              .where((i) => i.type == SettlementItemType.loadPay)
              .toList();
          final deductions = items
              .where((i) => i.type == SettlementItemType.fuelDeduction)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settlement #${settlement.id.substring(0, 8).toUpperCase()}',
                              style: FluentTheme.of(context).typography.title,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Period: ${dateFormat.format(settlement.startDate)} - ${dateFormat.format(settlement.endDate)}',
                              style: FluentTheme.of(context).typography.body,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: settlement.status.name == 'paid'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: settlement.status.name == 'paid'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Text(
                            settlement.status.name.toUpperCase(),
                            style: TextStyle(
                              color: settlement.status.name == 'paid'
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Financial Summary
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Gross Revenue',
                        currencyFormat.format(settlement.totalEarnings),
                        FluentIcons.money_24_regular,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Deductions',
                        currencyFormat.format(settlement.totalDeductions),
                        FluentIcons.subtract_circle_24_regular,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Net Payout',
                        currencyFormat.format(settlement.netPayout),
                        FluentIcons.wallet_24_regular,
                        Colors.green,
                        isMain: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Line Items - Loads
                Text(
                  'Loads & Earnings',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Trip #',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Description',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Amount',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      ...loads.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: FluentTheme.of(
                                  context,
                                ).resources.dividerStrokeColorDefault,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item.description.split(':').last.trim(),
                                ),
                              ),
                              Expanded(flex: 4, child: Text(item.description)),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormat.format(item.amount),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Line Items - Deductions
                Text(
                  'Deductions & Fuel',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Reference',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Description',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Amount',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      ...deductions.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: FluentTheme.of(
                                  context,
                                ).resources.dividerStrokeColorDefault,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(item.referenceId ?? '-'),
                              ),
                              Expanded(flex: 4, child: Text(item.description)),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormat.format(item.amount),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String amount,
    IconData icon,
    Color color, {
    bool isMain = false,
  }) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: theme.typography.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: isMain
                ? theme.typography.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  )
                : theme.typography.title,
          ),
        ],
      ),
    );
  }
}
