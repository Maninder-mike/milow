import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/load.dart';

/// Line item for quote
class QuoteLineItem {
  String type;
  String description;
  double rate;
  double quantity;
  String unit; // per mile, flat, per hour, percentage

  QuoteLineItem({
    this.type = 'Linehaul',
    this.description = '',
    this.rate = 0.0,
    this.quantity = 1.0,
    this.unit = 'flat',
  });

  double get total => rate * quantity;
}

/// Dialog for building a quote for a load
class LoadQuoteDialog extends StatefulWidget {
  const LoadQuoteDialog({
    required this.load,
    required this.onPublish,
    super.key,
  });

  final Load load;
  final Future<void> Function({
    required List<QuoteLineItem> lineItems,
    required DateTime? deliveryStartDate,
    required DateTime? deliveryEndDate,
    required String notes,
    required String status,
  })
  onPublish;

  @override
  State<LoadQuoteDialog> createState() => _LoadQuoteDialogState();
}

class _LoadQuoteDialogState extends State<LoadQuoteDialog> {
  // Quote Line Items
  final List<QuoteLineItem> _lineItems = [
    QuoteLineItem(
      type: 'Linehaul',
      description: 'Base freight rate',
      rate: 0.0,
      quantity: 1.0,
      unit: 'flat',
    ),
  ];

  // Quote metadata
  DateTime? _pickupDate;
  DateTime? _deliveryDate;
  DateTime? _expiresOn;
  String _quoteStatus = 'draft';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _refNumberController = TextEditingController();

  // Charge Types
  final List<String> _chargeTypes = [
    'Linehaul',
    'Fuel Surcharge',
    'Accessorial',
    'Detention',
    'Layover',
    'TONU',
    'Lumper',
    'Stop Off',
    'Hazmat',
    'Reefer',
    'Other',
  ];

  // Units
  final List<String> _units = ['flat', 'per mile', 'per hour', '%'];

  // Status options
  final List<String> _statusOptions = ['draft', 'sent', 'won', 'lost'];

  double get _quoteTotal =>
      _lineItems.fold(0.0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    _pickupDate = widget.load.pickup.date;
    _deliveryDate = widget.load.delivery.date;
    _expiresOn = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _poNumberController.dispose();
    _refNumberController.dispose();
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(QuoteLineItem());
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
      title: Row(
        children: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_left_24_regular),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build Quote',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Trip #${widget.load.tripNumber} • ${widget.load.loadReference}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(_quoteStatus).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _quoteStatus.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(_quoteStatus),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            // LOAD SUMMARY CARD
            // ─────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              child: Row(
                children: [
                  // Origin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FluentIcons.location_24_regular,
                              size: 16,
                              color: theme.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ORIGIN',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.resources.textFillColorTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.load.pickup.companyName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.load.pickup.city}, ${widget.load.pickup.state}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        if (_pickupDate != null)
                          Text(
                            dateFormat.format(_pickupDate!),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.resources.textFillColorTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      FluentIcons.arrow_right_24_regular,
                      color: theme.resources.textFillColorTertiary,
                    ),
                  ),
                  // Destination
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FluentIcons.location_24_filled,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'DESTINATION',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.resources.textFillColorTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.load.delivery.companyName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.load.delivery.city}, ${widget.load.delivery.state}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        if (_deliveryDate != null)
                          Text(
                            dateFormat.format(_deliveryDate!),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.resources.textFillColorTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Cargo Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: theme.resources.cardStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'CARGO',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.resources.textFillColorTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.load.weight.toStringAsFixed(0)} lbs',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.load.quantity} units',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        if (widget.load.goods.isNotEmpty)
                          Text(
                            widget.load.goods,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.resources.textFillColorTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // REFERENCE NUMBERS
            // ─────────────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'PO Number',
                    child: TextBox(
                      controller: _poNumberController,
                      placeholder: 'Customer PO#',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Reference Number',
                    child: TextBox(
                      controller: _refNumberController,
                      placeholder: 'Internal Ref#',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Quote Status',
                    child: ComboBox<String>(
                      value: _quoteStatus,
                      items: _statusOptions
                          .map(
                            (s) => ComboBoxItem<String>(
                              value: s,
                              child: Text(s.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _quoteStatus = v ?? 'draft'),
                      isExpanded: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Expires On',
                    child: DatePicker(
                      selected: _expiresOn,
                      onChanged: (d) => setState(() => _expiresOn = d),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // CHARGES TABLE
            // ─────────────────────────────────────────────────────────────
            Text(
              'CHARGES',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.resources.textFillColorTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.resources.subtleFillColorSecondary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            'TYPE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'DESCRIPTION',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'RATE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'QTY',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'UNIT',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'TOTAL',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  // Line Items
                  ..._lineItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.resources.cardStrokeColorDefault
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: _buildChargeRow(item, index),
                    );
                  }),
                  // Add Line Item
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Button(
                        onPressed: _addLineItem,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.add_24_regular,
                              size: 16,
                              color: theme.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add Charge',
                              style: TextStyle(color: theme.accentColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Total Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        Text(
                          'QUOTE TOTAL',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '\$${_quoteTotal.toStringAsFixed(2)} USD',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // NOTES
            // ─────────────────────────────────────────────────────────────
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Terms, conditions, or special instructions...',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  FluentIcons.info_24_regular,
                  size: 12,
                  color: theme.resources.textFillColorTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Notes are visible to customers on the quote',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onPublish(
              lineItems: _lineItems,
              deliveryStartDate: _pickupDate,
              deliveryEndDate: _deliveryDate,
              notes: _notesController.text,
              status: _quoteStatus,
            );
            if (mounted) Navigator.pop(context);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.send_24_regular, size: 16),
              const SizedBox(width: 8),
              Text(_quoteStatus == 'draft' ? 'Save Draft' : 'Send Quote'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChargeRow(QuoteLineItem item, int index) {
    return Row(
      children: [
        // Type
        SizedBox(
          width: 150,
          child: ComboBox<String>(
            value: item.type,
            items: _chargeTypes
                .map((t) => ComboBoxItem<String>(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => item.type = v);
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),
        // Description
        Expanded(
          flex: 2,
          child: TextBox(
            placeholder: 'Description',
            onChanged: (v) => item.description = v,
          ),
        ),
        const SizedBox(width: 8),
        // Rate
        SizedBox(
          width: 100,
          child: TextBox(
            placeholder: '\$0.00',
            onChanged: (v) {
              setState(() {
                item.rate = double.tryParse(v) ?? 0.0;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        // Quantity
        SizedBox(
          width: 80,
          child: TextBox(
            placeholder: '1',
            onChanged: (v) {
              setState(() {
                item.quantity = double.tryParse(v) ?? 1.0;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        // Unit
        SizedBox(
          width: 100,
          child: ComboBox<String>(
            value: item.unit,
            items: _units
                .map((u) => ComboBoxItem<String>(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => item.unit = v);
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),
        // Total
        SizedBox(
          width: 100,
          child: Text(
            '\$${item.total.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        // Delete
        IconButton(
          icon: Icon(
            FluentIcons.delete_24_regular,
            color: _lineItems.length > 1 ? AppColors.error : AppColors.neutral,
            size: 18,
          ),
          onPressed: _lineItems.length > 1
              ? () => _removeLineItem(index)
              : null,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.neutral;
      case 'sent':
        return AppColors.info;
      case 'won':
        return AppColors.success;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.neutral;
    }
  }
}
