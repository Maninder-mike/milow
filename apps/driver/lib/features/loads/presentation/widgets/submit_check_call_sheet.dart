import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/check_call_service.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class SubmitCheckCallSheet extends StatefulWidget {
  final CheckCall checkCall;
  final VoidCallback onSubmitted;

  const SubmitCheckCallSheet({
    required this.checkCall,
    required this.onSubmitted,
    super.key,
  });

  @override
  State<SubmitCheckCallSheet> createState() => _SubmitCheckCallSheetState();
}

class _SubmitCheckCallSheetState extends State<SubmitCheckCallSheet> {
  final _commentController = TextEditingController();
  final _valueController = TextEditingController();
  DateTime? _selectedEta;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    
    final responseData = <String, dynamic>{};
    
    switch (widget.checkCall.type) {
      case CheckCallType.location:
        responseData['lat'] = 34.0522; // Mocked
        responseData['lng'] = -118.2437; // Mocked
        responseData['address'] = 'Los Angeles, CA';
        break;
      case CheckCallType.temperature:
        responseData['temp'] = double.tryParse(_valueController.text) ?? 0.0;
        break;
      case CheckCallType.weight:
        responseData['weight'] = double.tryParse(_valueController.text) ?? 0.0;
        break;
      case CheckCallType.eta:
        responseData['eta'] = _selectedEta?.toIso8601String();
        break;
      case CheckCallType.custom:
        responseData['comment'] = _commentController.text;
        break;
    }

    final service = context.read<CheckCallService>();
    final result = await service.submitResponse(widget.checkCall.id, responseData);
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit: ${failure.message}')),
          );
        },
        (success) {
          widget.onSubmitted();
          Navigator.pop(context);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.shapeL)),
      ),
      padding: EdgeInsets.fromLTRB(tokens.spacingL, tokens.spacingL, tokens.spacingL, tokens.spacingL + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submit Response',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Gap(8),
          Text(
            widget.checkCall.prompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const Gap(24),
          _buildInputFields(theme, tokens),
          const Gap(32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('SUBMIT RESPONSE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields(ThemeData theme, DesignTokens tokens) {
    switch (widget.checkCall.type) {
      case CheckCallType.location:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(tokens.shapeM),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.gps_fixed, color: theme.colorScheme.primary),
              const Gap(12),
              const Expanded(
                child: Text('Current GPS position will be attached to this response.'),
              ),
            ],
          ),
        );
      case CheckCallType.temperature:
        return TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Temperature (°F/°C)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.thermostat),
          ),
        );
      case CheckCallType.weight:
        return TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Weight',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.scale),
          ),
        );
      case CheckCallType.eta:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _selectedEta == null 
                ? 'Select Estimated Time of Arrival' 
                : 'ETA: ${DateFormat.yMMMd().add_Hm().format(_selectedEta!)}',
          ),
          trailing: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (date != null) {
              if (!mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() {
                  _selectedEta = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                });
              }
            }
          },
        );
      case CheckCallType.custom:
        return TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Your Response',
            hintText: 'Enter any comments or requested information...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        );
    }
  }
}
