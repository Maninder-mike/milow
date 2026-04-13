import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:milow_core/milow_core.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';
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
  final _trailerIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isSafeToOperate = true;
  bool _isLoading = false;
  bool _isLocationLoading = false;

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
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationController.text = 'Location services disabled';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationController.text = 'Permission denied';
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationController.text = 'Permission denied forever';
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _locationController.text = '${p.street}, ${p.locality}, ${p.administrativeArea}';
      } else {
        _locationController.text = '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      _locationController.text = 'Error capturing location';
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _trailerIdController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _signatureController.dispose();
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
    if (_signatureController.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Signature Required'),
          content: const Text('Please provide your signature before submitting.'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(dvirRepositoryProvider);

      // In a real app, we would upload the signature image to Supabase Storage first.
      // For now, we'll simulate the upload and get a URL.
      // final signatureBytes = await _signatureController.toPngBytes();
      // final signatureUrl = await repo.uploadSignature(signatureBytes);
      const signatureUrl = 'https://placeholder.com/signature_raw_data_mock';

      final result = await repo.createInspection(
        vehicleId: widget.vehicleId,
        trailerId: _trailerIdController.text.isEmpty
            ? null
            : _trailerIdController.text,
        location: _locationController.text.isEmpty
            ? null
            : _locationController.text,
        inspectionType: _inspectionType,
        isSafeToOperate: _isSafeToOperate,
        odometer: int.tryParse(_odometerController.text),
        defects: _defects,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        driverSignatureUrl: signatureUrl,
      );

      result.fold(
        (failure) => _handleFailure(failure),
        (report) {
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
        },
      );
    } catch (e) {
      _handleFailure(UnexpectedFailure(e.toString(), originalError: e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFailure(Failure failure) {
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Error'),
          content: Text(failure.message),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
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
            RadioGroup<DVIRInspectionType>(
              groupValue: _inspectionType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _inspectionType = value);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioButton<DVIRInspectionType>(
                      value: DVIRInspectionType.preTrip,
                      content: const Text('Pre-Trip'),
                    ),
                  ),
                  Expanded(
                    child: RadioButton<DVIRInspectionType>(
                      value: DVIRInspectionType.postTrip,
                      content: const Text('Post-Trip'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle Info Row
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Odometer',
                    child: TextBox(
                      controller: _odometerController,
                      placeholder: 'Current mileage',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Trailer ID (Optional)',
                    child: TextBox(
                      controller: _trailerIdController,
                      placeholder: 'e.g., T-101',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            InfoLabel(
              label: 'Location',
              child: TextBox(
                controller: _locationController,
                placeholder: _isLocationLoading
                    ? 'Capturing location...'
                    : 'Physical location of inspection',
                prefix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _isLocationLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : const Icon(FluentIcons.location_16_regular, size: 16),
                ),
                suffix: IconButton(
                  icon: const Icon(FluentIcons.arrow_sync_16_regular),
                  onPressed: _isLocationLoading ? null : _captureLocation,
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
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Driver Signature
            Text(
              'Driver Signature *',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                ),
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Signature(
                    controller: _signatureController,
                    height: 120,
                    backgroundColor: Colors.white,
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HyperlinkButton(
                        onPressed: () => _signatureController.clear(),
                        child: const Text('Clear Signature'),
                      ),
                    ],
                  ),
                ],
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
                id: const Uuid().v4(),
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
