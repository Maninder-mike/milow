import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/dvir_report.dart';
import '../../data/repositories/dvir_repository.dart';

/// Dialog for creating DVIR (Driver Vehicle Inspection Report)
class DVIRInspectionDialog extends ConsumerStatefulWidget {
  final String vehicleId;
  final int? currentOdometer;
  final VoidCallback? onSaved;

  const DVIRInspectionDialog({
    super.key,
    required this.vehicleId,
    this.currentOdometer,
    this.onSaved,
  });

  @override
  ConsumerState<DVIRInspectionDialog> createState() =>
      _DVIRInspectionDialogState();
}

class _DVIRInspectionDialogState extends ConsumerState<DVIRInspectionDialog> {
  DVIRInspectionType _inspectionType = DVIRInspectionType.preTrip;
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSafeToOperate = true;
  bool _isLoading = false;

  // Checklist state
  final Map<DVIRCategory, bool> _checkedItems = {};
  final List<DVIRDefect> _defects = [];

  @override
  void initState() {
    super.initState();
    if (widget.currentOdometer != null) {
      _odometerController.text = widget.currentOdometer.toString();
    }
    // Initialize all categories as checked (passed)
    for (final category in DVIRCategory.values) {
      _checkedItems[category] = true;
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addDefect(DVIRCategory category) {
    showDialog(
      context: context,
      builder: (context) => _AddDefectDialog(
        category: category,
        onAdd: (defect) {
          setState(() {
            _defects.add(defect);
            _checkedItems[category] = false;
            // Auto-mark unsafe if critical defect
            if (defect.severity == DefectSeverity.critical) {
              _isSafeToOperate = false;
            }
          });
        },
      ),
    );
  }

  void _removeDefect(int index) {
    setState(() {
      final defect = _defects.removeAt(index);
      // Check if category has any remaining defects
      final hasDefectsInCategory = _defects.any(
        (d) => d.category == defect.category,
      );
      if (!hasDefectsInCategory) {
        _checkedItems[defect.category] = true;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(dvirRepositoryProvider);
      await repo.createInspection(
        vehicleId: widget.vehicleId,
        inspectionType: _inspectionType,
        isSafeToOperate: _isSafeToOperate,
        odometer: int.tryParse(_odometerController.text),
        defects: _defects,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Invalidate providers
      ref.invalidate(dvirHistoryProvider(widget.vehicleId));

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();

        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('DVIR Submitted'),
            content: Text(
              _defects.isEmpty
                  ? 'No defects found'
                  : '${_defects.length} defect(s) reported',
            ),
            severity: _defects.isEmpty
                ? InfoBarSeverity.success
                : InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('DVIR Inspection'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inspection Type Toggle
            Row(
              children: [
                Expanded(
                  child: RadioButton(
                    checked: _inspectionType == DVIRInspectionType.preTrip,
                    onChanged: (checked) {
                      if (checked) {
                        setState(
                          () => _inspectionType = DVIRInspectionType.preTrip,
                        );
                      }
                    },
                    content: const Text('Pre-Trip'),
                  ),
                ),
                Expanded(
                  child: RadioButton(
                    checked: _inspectionType == DVIRInspectionType.postTrip,
                    onChanged: (checked) {
                      if (checked) {
                        setState(
                          () => _inspectionType = DVIRInspectionType.postTrip,
                        );
                      }
                    },
                    content: const Text('Post-Trip'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Odometer
            InfoLabel(
              label: 'Odometer',
              child: SizedBox(
                width: 200,
                child: TextBox(
                  controller: _odometerController,
                  placeholder: 'Current mileage',
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Inspection Checklist
            Text(
              'Inspection Checklist',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap an item to report a defect. Green = OK, Red = Defect found.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DVIRCategory.values.map((category) {
                final isOk = _checkedItems[category] ?? true;
                final defectCount = _defects
                    .where((d) => d.category == category)
                    .length;

                return GestureDetector(
                  onTap: () => _addDefect(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isOk
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOk
                            ? Colors.green.withValues(alpha: 0.5)
                            : Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOk
                              ? FluentIcons.checkmark_circle_16_filled
                              : FluentIcons.error_circle_16_filled,
                          size: 16,
                          color: isOk ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.displayName,
                          style: TextStyle(
                            color: isOk ? Colors.green : Colors.red,
                          ),
                        ),
                        if (defectCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$defectCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Defects List
            if (_defects.isNotEmpty) ...[
              Text(
                'Defects Found (${_defects.length})',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 8),
              ...List.generate(_defects.length, (index) {
                final defect = _defects[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: defect.severity == DefectSeverity.critical
                          ? Colors.red
                          : defect.severity == DefectSeverity.major
                          ? Colors.orange
                          : Colors.yellow,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${defect.category.displayName} - ${defect.severity.displayName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(defect.description),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete_16_regular),
                        onPressed: () => _removeDefect(index),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Safe to Operate Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSafeToOperate
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSafeToOperate
                        ? FluentIcons.shield_checkmark_24_regular
                        : FluentIcons.shield_error_24_regular,
                    color: _isSafeToOperate ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isSafeToOperate
                          ? 'Vehicle is SAFE to operate'
                          : 'Vehicle is NOT SAFE to operate',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isSafeToOperate ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  ToggleSwitch(
                    checked: _isSafeToOperate,
                    onChanged: (value) =>
                        setState(() => _isSafeToOperate = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Additional notes',
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Submit DVIR'),
        ),
      ],
    );
  }
}

/// Dialog to add a single defect
class _AddDefectDialog extends StatefulWidget {
  final DVIRCategory category;
  final void Function(DVIRDefect) onAdd;

  const _AddDefectDialog({required this.category, required this.onAdd});

  @override
  State<_AddDefectDialog> createState() => _AddDefectDialogState();
}

class _AddDefectDialogState extends State<_AddDefectDialog> {
  final _descriptionController = TextEditingController();
  DefectSeverity _severity = DefectSeverity.minor;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Report ${widget.category.displayName} Defect'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Severity',
            child: ComboBox<DefectSeverity>(
              value: _severity,
              isExpanded: true,
              items: DefectSeverity.values
                  .map(
                    (s) => ComboBoxItem(value: s, child: Text(s.displayName)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _severity = value);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Description *',
            child: TextBox(
              controller: _descriptionController,
              placeholder: 'Describe the defect...',
              maxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_descriptionController.text.isEmpty) {
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('Description required'),
                  severity: InfoBarSeverity.warning,
                  onClose: close,
                ),
              );
              return;
            }
            widget.onAdd(
              DVIRDefect(
                category: widget.category,
                description: _descriptionController.text,
                severity: _severity,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Add Defect'),
        ),
      ],
    );
  }
}
