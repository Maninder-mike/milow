import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/maintenance_record.dart';
import '../../data/repositories/maintenance_repository.dart';

/// Dialog to add a new maintenance/service record
class AddMaintenanceDialog extends ConsumerStatefulWidget {
  final String vehicleId;
  final VoidCallback? onSaved;

  const AddMaintenanceDialog({
    super.key,
    required this.vehicleId,
    this.onSaved,
  });

  @override
  ConsumerState<AddMaintenanceDialog> createState() =>
      _AddMaintenanceDialogState();
}

class _AddMaintenanceDialogState extends ConsumerState<AddMaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();
  MaintenanceServiceType _serviceType = MaintenanceServiceType.oilChange;
  final _descriptionController = TextEditingController();
  final _odometerController = TextEditingController();
  final _costController = TextEditingController();
  final _performedByController = TextEditingController();
  final _notesController = TextEditingController();
  final _nextDueOdometerController = TextEditingController();
  DateTime _performedAt = DateTime.now();
  DateTime? _nextDueDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _odometerController.dispose();
    _costController.dispose();
    _performedByController.dispose();
    _notesController.dispose();
    _nextDueOdometerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      await repo.addServiceRecord(
        vehicleId: widget.vehicleId,
        serviceType: _serviceType,
        performedAt: _performedAt,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        odometerAtService: _odometerController.text.isEmpty
            ? null
            : int.tryParse(_odometerController.text),
        cost: _costController.text.isEmpty
            ? null
            : double.tryParse(_costController.text),
        performedBy: _performedByController.text.isEmpty
            ? null
            : _performedByController.text,
        nextDueOdometer: _nextDueOdometerController.text.isEmpty
            ? null
            : int.tryParse(_nextDueOdometerController.text),
        nextDueDate: _nextDueDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Invalidate providers to refresh data
      ref.invalidate(maintenanceRecordsProvider(widget.vehicleId));

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error Saving'),
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
      title: const Text('Add Service Record'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Service Type
              InfoLabel(
                label: 'Service Type *',
                child: ComboBox<MaintenanceServiceType>(
                  value: _serviceType,
                  isExpanded: true,
                  items: MaintenanceServiceType.values
                      .map(
                        (type) => ComboBoxItem(
                          value: type,
                          child: Text(type.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _serviceType = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Date Performed
              InfoLabel(
                label: 'Date Performed *',
                child: DatePicker(
                  selected: _performedAt,
                  onChanged: (date) => setState(() => _performedAt = date),
                ),
              ),
              const SizedBox(height: 16),

              // Odometer
              InfoLabel(
                label: 'Odometer (miles)',
                child: TextBox(
                  controller: _odometerController,
                  placeholder: 'e.g., 125000',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),

              // Cost
              InfoLabel(
                label: 'Cost (\$)',
                child: TextBox(
                  controller: _costController,
                  placeholder: 'e.g., 150.00',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),

              // Performed By
              InfoLabel(
                label: 'Performed By',
                child: TextBox(
                  controller: _performedByController,
                  placeholder: 'Mechanic name or shop',
                ),
              ),
              const SizedBox(height: 16),

              // Description
              InfoLabel(
                label: 'Description',
                child: TextBox(
                  controller: _descriptionController,
                  placeholder: 'Additional details',
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 24),

              // Next Service Section
              Text(
                'Next Service Due (Optional)',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: 'At Odometer',
                      child: TextBox(
                        controller: _nextDueOdometerController,
                        placeholder: 'e.g., 140000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Or By Date',
                      child: DatePicker(
                        selected: _nextDueDate,
                        onChanged: (date) =>
                            setState(() => _nextDueDate = date),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              InfoLabel(
                label: 'Notes',
                child: TextBox(
                  controller: _notesController,
                  placeholder: 'Any additional notes',
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
