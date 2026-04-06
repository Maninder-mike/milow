import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/dispatch/presentation/providers/load_providers.dart';

class CreateCheckCallDialog extends ConsumerStatefulWidget {
  final String loadId;
  final String driverId;

  const CreateCheckCallDialog({
    super.key,
    required this.loadId,
    required this.driverId,
  });

  @override
  ConsumerState<CreateCheckCallDialog> createState() => _CreateCheckCallDialogState();
}

class _CreateCheckCallDialogState extends ConsumerState<CreateCheckCallDialog> {
  CheckCallType _selectedType = CheckCallType.custom;
  final _promptController = TextEditingController();
  bool _isSubmitting = false;

  final Map<CheckCallType, String> _defaultPrompts = {
    CheckCallType.location: 'Please share your current location and status.',
    CheckCallType.temperature: 'Please provide the current reefer temperature.',
    CheckCallType.weight: 'Please provide the loaded weight from the scale ticket.',
    CheckCallType.eta: 'Please provide your updated ETA to the next stop.',
    CheckCallType.custom: '',
  };

  @override
  void initState() {
    super.initState();
    _promptController.text = _defaultPrompts[_selectedType]!;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_promptController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final repository = ref.read(loadRepositoryProvider);
    final result = await repository.createCheckCall(
      loadId: widget.loadId,
      driverId: widget.driverId,
      type: _selectedType,
      prompt: _promptController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      result.fold(
        (failure) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Error'),
              content: Text(failure.message),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        },
        (_) => Navigator.pop(context, true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(
        'Request Structured Check-Call',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Request Type:'),
          const SizedBox(height: 8),
          ComboBox<CheckCallType>(
            value: _selectedType,
            items: CheckCallType.values.map((type) {
              return ComboBoxItem(
                value: type,
                child: Text(type.label),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                  _promptController.text = _defaultPrompts[val]!;
                });
              }
            },
            isExpanded: true,
          ),
          const SizedBox(height: 16),
          const Text('Prompt / Instructions:'),
          const SizedBox(height: 8),
          TextBox(
            controller: _promptController,
            placeholder: 'Enter instructions for the driver...',
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Text(
            'This will appear as a high-priority notification on the driver\'s device.',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting 
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2)) 
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
