import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/driver_pay_config.dart';
import '../providers/settlement_providers.dart';

class DriverPayConfigDialog extends ConsumerStatefulWidget {
  final String driverId;
  final String driverName;
  final DriverPayConfig? existingConfig;

  const DriverPayConfigDialog({
    super.key,
    required this.driverId,
    required this.driverName,
    this.existingConfig,
  });

  @override
  ConsumerState<DriverPayConfigDialog> createState() =>
      _DriverPayConfigDialogState();
}

class _DriverPayConfigDialogState extends ConsumerState<DriverPayConfigDialog> {
  late DriverPayType _payType;
  final _payValueController = TextEditingController();
  final _emptyCpmController = TextEditingController();
  final _stopOffPayController = TextEditingController();
  final _detentionPayController = TextEditingController();
  final _layoverPayController = TextEditingController();

  List<RecurringDeduction> _deductions = [];

  @override
  void initState() {
    super.initState();
    final config = widget.existingConfig;
    if (config != null) {
      _payType = config.payType;
      _payValueController.text = config.payValue.toString();
      _emptyCpmController.text = config.emptyCpm?.toString() ?? '';
      _stopOffPayController.text = config.stopOffPay?.toString() ?? '';
      _detentionPayController.text =
          config.detentionPayPerHour?.toString() ?? '';
      _layoverPayController.text = config.layoverPay?.toString() ?? '';
      _deductions = List.from(config.recurringDeductions);
    } else {
      _payType = DriverPayType.percentage;
    }
  }

  @override
  void dispose() {
    _payValueController.dispose();
    _emptyCpmController.dispose();
    _stopOffPayController.dispose();
    _detentionPayController.dispose();
    _layoverPayController.dispose();
    super.dispose();
  }

  void _addDeduction() {
    setState(() {
      _deductions.add(
        RecurringDeduction(
          name: 'New Deduction',
          amount: 0,
          frequency: 'per_settlement',
        ),
      );
    });
  }

  void _removeDeduction(int index) {
    setState(() {
      _deductions.removeAt(index);
    });
  }

  void _updateDeduction(int index, RecurringDeduction modified) {
    setState(() {
      _deductions[index] = modified;
    });
  }

  Future<void> _save() async {
    final payValue = double.tryParse(_payValueController.text) ?? 0;

    // Make sure we have a valid base pay
    if (payValue <= 0) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Error'),
          content: const Text('Please enter a valid base pay value.'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    final newConfig = DriverPayConfig(
      id: widget.existingConfig?.id ?? '',
      driverId: widget.driverId,
      payType: _payType,
      payValue: payValue,
      emptyCpm: double.tryParse(_emptyCpmController.text),
      stopOffPay: double.tryParse(_stopOffPayController.text),
      detentionPayPerHour: double.tryParse(_detentionPayController.text),
      layoverPay: double.tryParse(_layoverPayController.text),
      recurringDeductions: _deductions,
    );

    try {
      await ref.read(settlementRepositoryProvider).savePayConfig(newConfig);
      ref.invalidate(driverPayConfigProvider(widget.driverId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Save Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Pay Configuration: \${widget.driverName}'),
      constraints: const BoxConstraints(maxWidth: 600),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Base Pay Model',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ComboBox<DriverPayType>(
                    value: _payType,
                    isExpanded: true,
                    items: DriverPayType.values.map((t) {
                      return ComboBoxItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _payType = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextBox(
                    controller: _payValueController,
                    placeholder: _payType == DriverPayType.percentage
                        ? 'e.g. 75 (for 75%)'
                        : 'e.g. 0.65',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefix: _payType != DriverPayType.percentage
                        ? const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(FluentIcons.money_24_regular),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Accessorial Pay',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAmountRow('Empty CPM', _emptyCpmController),
            const SizedBox(height: 8),
            _buildAmountRow('Stop-Off Pay', _stopOffPayController),
            const SizedBox(height: 8),
            _buildAmountRow('Detention (Per Hour)', _detentionPayController),
            const SizedBox(height: 8),
            _buildAmountRow('Layover Pay', _layoverPayController),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recurring Deductions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Button(
                  onPressed: _addDeduction,
                  child: const Text('Add Deduction'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_deductions.isEmpty)
              const Text(
                'No recurring deductions set.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ..._deductions.asMap().entries.map((entry) {
              final index = entry.key;
              final deduction = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextBox(
                        placeholder: 'Deduction Name',
                        controller: TextEditingController(text: deduction.name),
                        onChanged: (v) => _updateDeduction(
                          index,
                          RecurringDeduction(
                            name: v,
                            amount: deduction.amount,
                            frequency: deduction.frequency,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextBox(
                        placeholder: 'Amount',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(r'$'),
                        ),
                        controller: TextEditingController(
                          text: deduction.amount.toString(),
                        ),
                        onChanged: (v) {
                          final val = double.tryParse(v) ?? 0;
                          _updateDeduction(
                            index,
                            RecurringDeduction(
                              name: deduction.name,
                              amount: val,
                              frequency: deduction.frequency,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ComboBox<String>(
                        value: deduction.frequency,
                        isExpanded: true,
                        items: ['per_settlement', 'weekly', 'monthly']
                            .map((f) => ComboBoxItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (f) {
                          if (f != null) {
                            _updateDeduction(
                              index,
                              RecurringDeduction(
                                name: deduction.name,
                                amount: deduction.amount,
                                frequency: f,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        FluentIcons.delete_24_regular,
                        color: Color(0xFFF44336),
                      ),
                      onPressed: () => _removeDeduction(index),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save Configuration')),
      ],
    );
  }

  Widget _buildAmountRow(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label)),
        Expanded(
          flex: 3,
          child: TextBox(
            controller: controller,
            placeholder: 'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(r'$'),
            ),
          ),
        ),
      ],
    );
  }
}
