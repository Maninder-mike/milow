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
    this.existingQuote,
    super.key,
  });

  final Load load;

  /// If provided, the dialog will be pre-populated for editing
  final dynamic existingQuote; // Quote from quote.dart (avoid circular import)
  final Future<void> Function({
    required List<QuoteLineItem> lineItems,
    required DateTime? deliveryStartDate,
    required DateTime? deliveryEndDate,
    required String notes,
    required String status,
    required String? poNumber,
    required String? loadReference,
    required DateTime? expiresOn,
  })
  onPublish;

  @override
  State<LoadQuoteDialog> createState() => _LoadQuoteDialogState();
}

class _LoadQuoteDialogState extends State<LoadQuoteDialog> {
  // Quote Line Items
  late List<QuoteLineItem> _lineItems;

  // Quote metadata
  DateTime? _pickupDate;
  DateTime? _deliveryDate;
  DateTime? _expiresOn;
  String _quoteStatus = 'draft';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _refNumberController = TextEditingController();

  // Status options
  final List<String> _statusOptions = ['draft', 'sent', 'won', 'lost'];

  double get _quoteTotal =>
      _lineItems.fold(0.0, (sum, item) => sum + item.total);

  @override
  @override
  void initState() {
    super.initState();
    _pickupDate = widget.load.pickup.date;
    _deliveryDate = widget.load.delivery.date;
    _expiresOn = DateTime.now().add(const Duration(days: 7));
    _refNumberController.text = widget.load.loadReference;
    _poNumberController.text = widget.load.poNumber ?? '';

    // Pre-populate from existing quote if editing
    if (widget.existingQuote != null) {
      final existing = widget.existingQuote;
      _quoteStatus = existing.status ?? 'draft';
      _notesController.text = existing.notes ?? '';
      _expiresOn = existing.expiresOn;
      // Inherit loading reference from load if quote doesn't have it (or override)
      if (existing.loadReference.isNotEmpty) {
        _refNumberController.text = existing.loadReference;
      }

      // Convert existing line items
      final existingItems = existing.lineItems as List<dynamic>?;
      if (existingItems != null && existingItems.isNotEmpty) {
        _lineItems = existingItems.map((item) {
          // Check if item is already QuoteLineItem or needs conversion (from JSON/Map)
          if (item is QuoteLineItem) return item;
          // If it's from JSON it might be a Map, or passed as object depending on how it's stored.
          // The Quote model definition suggests List<QuoteLineItem> but let's be safe.
          return QuoteLineItem(
            type: item.type ?? 'Linehaul',
            description: item.description ?? '',
            rate: item.rate ?? 0.0,
            quantity: item.quantity ?? 1.0,
            unit: item.unit ?? 'flat',
          );
        }).toList();
      } else {
        _lineItems = [QuoteLineItem()];
      }
    } else {
      _lineItems = [QuoteLineItem()];
    }
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Expanded(
                          flex: 3,
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
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
                        const SizedBox(width: 48), // Padding + Icon space
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
                      child: _ChargeRow(
                        key: ObjectKey(
                          item,
                        ), // Important: preserve state during reorders/edits
                        item: item,
                        onDelete: () => _removeLineItem(index),
                        onChanged: () {
                          // Trigger rebuild to update total
                          setState(() {});
                        },
                      ),
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
            final navigator = Navigator.of(context);
            await widget.onPublish(
              lineItems: _lineItems,
              deliveryStartDate: _pickupDate,
              deliveryEndDate: _deliveryDate,
              notes: _notesController.text,
              status: _quoteStatus,
              poNumber: _poNumberController.text,
              loadReference: _refNumberController.text,
              expiresOn: _expiresOn,
            );
            if (mounted) navigator.pop();
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

class _ChargeRow extends StatefulWidget {
  final QuoteLineItem item;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ChargeRow({
    required this.item,
    required this.onDelete,
    required this.onChanged,
    super.key,
  });

  @override
  State<_ChargeRow> createState() => _ChargeRowState();
}

class _ChargeRowState extends State<_ChargeRow> {
  late TextEditingController _descController;
  late TextEditingController _rateController;
  late TextEditingController _qtyController;

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
  final List<String> _units = ['flat', 'per mile', 'per hour', '%'];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.item.description);
    _rateController = TextEditingController(text: widget.item.rate.toString());
    _qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );

    _descController.addListener(_updateItem);
    _rateController.addListener(_updateItem);
    _qtyController.addListener(_updateItem);
  }

  void _updateItem() {
    widget.item.description = _descController.text;
    widget.item.rate = double.tryParse(_rateController.text) ?? 0.0;
    widget.item.quantity = double.tryParse(_qtyController.text) ?? 1.0;
    widget.onChanged();
  }

  @override
  void dispose() {
    _descController.dispose();
    _rateController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Type
        Expanded(
          flex: 3,
          child: ComboBox<String>(
            value: widget.item.type,
            items: _chargeTypes
                .map((t) => ComboBoxItem<String>(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => widget.item.type = v);
                widget.onChanged();
              }
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),
        // Description
        Expanded(
          flex: 5,
          child: TextBox(
            placeholder: 'Description',
            controller: _descController,
          ),
        ),
        const SizedBox(width: 8),
        // Rate
        Expanded(
          flex: 2,
          child: TextBox(placeholder: '\$0.00', controller: _rateController),
        ),
        const SizedBox(width: 8),
        // Quantity
        Expanded(
          flex: 1,
          child: TextBox(placeholder: '1', controller: _qtyController),
        ),
        const SizedBox(width: 8),
        // Unit
        Expanded(
          flex: 2,
          child: ComboBox<String>(
            value: widget.item.unit,
            items: _units
                .map((u) => ComboBoxItem<String>(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => widget.item.unit = v);
                widget.onChanged();
              }
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),
        // Total
        Expanded(
          flex: 2,
          child: Text(
            '\$${widget.item.total.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        // Delete
        IconButton(
          icon: Icon(
            FluentIcons.delete_24_regular,
            size: 16,
            color: AppColors.error,
          ),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }
}
