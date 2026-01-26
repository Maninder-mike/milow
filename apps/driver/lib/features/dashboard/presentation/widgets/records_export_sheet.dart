import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

// import 'package:milow_core/milow_core.dart'; // Verify if needed, usually core/constants/design_tokens.dart is enough if using extension

class RecordsExportSheet extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final String initialFilter;
  final List<String> initialTripColumns;
  final List<String> initialFuelColumns;
  final Function(DateTimeRange?, String, List<String>, List<String>, bool)
  onDownloadCSV;
  final Function(DateTimeRange?, String, List<String>, List<String>, bool)
  onDownloadPDF;
  final Function(List<String> tripCols, List<String> fuelCols)
  onSavePreferences;

  const RecordsExportSheet({
    required this.initialFilter,
    required this.initialTripColumns,
    required this.initialFuelColumns,
    required this.onDownloadCSV,
    required this.onDownloadPDF,
    required this.onSavePreferences,
    this.initialDateRange,
    super.key,
  });

  @override
  State<RecordsExportSheet> createState() => _RecordsExportSheetState();
}

class _RecordsExportSheetState extends State<RecordsExportSheet> {
  late DateTimeRange? _selectedDateRange;
  late String _selectedFilter;
  late List<String> _selectedTripColumns;
  late List<String> _selectedFuelColumns;
  bool _includeSummaryBanner = true;

  // Constants from RecordsListPage
  static const Map<String, String> tripColumnLabels = {
    'tripNumber': 'Trip #',
    'date': 'Date',
    'truck': 'Truck',
    'trailer': 'Trailer',
    'borderCrossing': 'Border Crossing',
    'from': 'From (Pickup)',
    'to': 'To (Delivery)',
    'miles': 'Miles/Km',
    'notes': 'Notes',
    'officialUse': 'Official Use',
  };

  static const Map<String, String> fuelColumnLabels = {
    'date': 'Date',
    'type': 'Type',
    'truck': 'Truck #',
    'location': 'Location',
    'quantity': 'Quantity',
    'odometer': 'Odometer',
    'cost': 'Cost',
  };

  @override
  void initState() {
    super.initState();
    _selectedDateRange = widget.initialDateRange;
    _selectedFilter = widget.initialFilter;
    _selectedTripColumns = List.from(widget.initialTripColumns);
    _selectedFuelColumns = List.from(widget.initialFuelColumns);
  }

  void _savePrefs() {
    widget.onSavePreferences(_selectedTripColumns, _selectedFuelColumns);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        final tokens = context.tokens;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(surface: tokens.surfaceContainer),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle handled by showModalBottomSheet property, or customizable here if needed.
          // Since we might use DraggableScrollableSheet later, putting a custom header is safer.
          // But implementing basic structure first.

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacingL,
              tokens.spacingM,
              tokens.spacingM,
              tokens.spacingM,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Export Records',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: tokens.subtleBorderColor),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Selector Card
                  _buildSectionLabel('Date Range'),
                  SizedBox(height: tokens.spacingS),
                  _buildDateRangeCard(),

                  SizedBox(height: tokens.spacingL),

                  // Filter Chips (Using visually cleaner SingleChoice)
                  // Note: The filter might be passed from parent, keeping it sync is good but
                  // typically exports might want to override the current list filter.
                  // For now, let's allow changing it, or maybe just display current context?
                  // The previous implementation used a dropdown. Let's make it a nice scrollable segment or chips.
                  // Actually, keeping the dropdown logic but making it look better.
                  _buildSectionLabel('Filter Type'),
                  SizedBox(height: tokens.spacingS),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Trips Only', 'Fuel Only'].map((
                        filter,
                      ) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: EdgeInsets.only(right: tokens.spacingS),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                              }
                            },
                            // M3 styling
                            showCheckmark: false,
                            labelStyle: textTheme.labelMedium?.copyWith(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : tokens.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            selectedColor: colorScheme.secondaryContainer,
                            backgroundColor: tokens.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.shapeFull,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : tokens.subtleBorderColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: tokens.spacingXL),

                  // Trip Columns
                  if (_selectedFilter != 'Fuel Only') ...[
                    _buildSectionLabel('Trip Fields'),
                    SizedBox(height: tokens.spacingS),
                    _buildColumnSelector(
                      tripColumnLabels,
                      _selectedTripColumns,
                      (updated) {
                        setState(() => _selectedTripColumns = updated);
                        _savePrefs();
                      },
                    ),
                    SizedBox(height: tokens.spacingXL),
                  ],

                  // Fuel Columns
                  if (_selectedFilter != 'Trips Only') ...[
                    _buildSectionLabel('Fuel Fields'),
                    SizedBox(height: tokens.spacingS),
                    _buildColumnSelector(
                      fuelColumnLabels,
                      _selectedFuelColumns,
                      (updated) {
                        setState(() => _selectedFuelColumns = updated);
                        _savePrefs();
                      },
                    ),
                    SizedBox(height: tokens.spacingXL),
                  ],

                  // Options
                  _buildSectionLabel('Options'),
                  SizedBox(height: tokens.spacingS),
                  _buildOptionSwitch(
                    'Include Summary Banner',
                    'Show totals for mileage and fuel cost',
                    _includeSummaryBanner,
                    (val) => setState(() => _includeSummaryBanner = val),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: tokens.subtleBorderColor),

          // Action Buttons
          Padding(
            padding: EdgeInsets.all(tokens.spacingL),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDownloadCSV(
                        _selectedDateRange,
                        _selectedFilter,
                        _selectedTripColumns,
                        _selectedFuelColumns,
                        _includeSummaryBanner,
                      );
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text('CSV / Excel'),
                    style: OutlinedButton.styleFrom(
                      // Match global 20px
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          tokens.shapeButton,
                        ), // 20
                      ),
                      padding: EdgeInsets.symmetric(vertical: tokens.spacingM),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacingM),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDownloadPDF(
                        _selectedDateRange,
                        _selectedFilter,
                        _selectedTripColumns,
                        _selectedFuelColumns,
                        _includeSummaryBanner,
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text('PDF Report'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          tokens.shapeButton,
                        ), // 20
                      ),
                      padding: EdgeInsets.symmetric(vertical: tokens.spacingM),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: context.tokens.textPrimary,
      ),
    );
  }

  Widget _buildDateRangeCard() {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final isSet = _selectedDateRange != null;

    String dateText = '';
    if (isSet) {
      dateText =
          '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}/${_selectedDateRange!.end.year}';
    }

    return TextField(
      readOnly: true,
      onTap: _pickDateRange,
      controller: TextEditingController(text: dateText),
      style: textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: 'Select Date Range',
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
        prefixIcon: Icon(
          Icons.date_range_rounded,
          color: tokens.textSecondary,
          size: 20,
        ),
        suffixIcon: isSet
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () => setState(() => _selectedDateRange = null),
                style: IconButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                ),
              )
            : Icon(Icons.arrow_drop_down_rounded, color: tokens.textSecondary),
        filled: true,
        fillColor: tokens.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacingM,
          vertical: tokens.spacingM,
        ),
      ),
    );
  }

  Widget _buildColumnSelector(
    Map<String, String> labels,
    List<String> selected,
    Function(List<String>) onChanged,
  ) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    // Split into selected (ordered) and available (unordered)
    final availableIds = labels.keys
        .where((k) => !selected.contains(k))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Active Columns (Reorderable)
        if (selected.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false, // We'll use custom handles
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                color: tokens.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(tokens.shapeS),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = selected.removeAt(oldIndex);
                selected.insert(newIndex, item);
                onChanged(selected);
              });
            },
            children: [
              for (int i = 0; i < selected.length; i++)
                Container(
                  key: ValueKey(selected[i]),
                  margin: EdgeInsets.only(bottom: tokens.spacingS),
                  decoration: BoxDecoration(
                    color: tokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                    border: Border.all(color: tokens.subtleBorderColor),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: null, // Maybe allow tap to edit?
                      borderRadius: BorderRadius.circular(tokens.shapeS),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacingM,
                          vertical: tokens.spacingS,
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: tokens.textTertiary,
                              ),
                            ),
                            SizedBox(width: tokens.spacingM),
                            Expanded(
                              child: Text(
                                labels[selected[i]] ?? selected[i],
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textPrimary,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                                color: tokens.textSecondary,
                              ),
                              onPressed: () {
                                // Prevent emptying if needed, but UX is better if we allow removal and user can see empty state
                                if (selected.length > 1) {
                                  final newList = List<String>.from(selected);
                                  newList.removeAt(i);
                                  onChanged(newList);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

        if (selected.isNotEmpty && availableIds.isNotEmpty)
          SizedBox(height: tokens.spacingM),

        // 2. Available Columns (Tap to add)
        if (availableIds.isNotEmpty) ...[
          Text(
            'Add Fields',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.spacingS),
          Wrap(
            spacing: tokens.spacingS,
            runSpacing: tokens.spacingS,
            children: availableIds.map((id) {
              return ActionChip(
                label: Text(labels[id] ?? id),
                onPressed: () {
                  final newList = List<String>.from(selected);
                  newList.add(id);
                  onChanged(newList);
                },
                avatar: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                backgroundColor: tokens.surfaceContainer,
                side: BorderSide(color: tokens.subtleBorderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.shapeS),
                ),
                labelStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textPrimary),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionSwitch(
    String label,
    String sublabel,
    bool value,
    Function(bool) onChanged,
  ) {
    final tokens = context.tokens;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        sublabel,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
