import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/constants/design_tokens.dart';

class DetentionDialog extends StatefulWidget {
  final Detention? initialDetention;

  const DetentionDialog({super.key, this.initialDetention});

  @override
  State<DetentionDialog> createState() => _DetentionDialogState();
}

class _DetentionDialogState extends State<DetentionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _approverController;
  late TextEditingController _notesController;

  // Duration state
  int _hours = 0;
  int _minutes = 0;
  bool _isLayover = false;

  @override
  void initState() {
    super.initState();
    _approverController = TextEditingController(
      text: widget.initialDetention?.approverName ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialDetention?.notes ?? '',
    );

    if (widget.initialDetention != null) {
      final inMinutes = widget.initialDetention!.duration.inMinutes;
      _hours = inMinutes ~/ 60;
      _minutes = inMinutes % 60;
      _isLayover = widget.initialDetention!.isLayover;
    }
  }

  @override
  void dispose() {
    _approverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _incrementHours() => setState(() => _hours++);
  void _decrementHours() =>
      setState(() => _hours = _hours > 0 ? _hours - 1 : 0);

  void _incrementMinutes() {
    setState(() {
      if (_minutes + 15 >= 60) {
        _hours++;
        _minutes = (_minutes + 15) % 60;
      } else {
        _minutes += 15;
      }
    });
  }

  void _decrementMinutes() {
    setState(() {
      if (_minutes - 15 < 0) {
        if (_hours > 0) {
          _hours--;
          _minutes = 60 + (_minutes - 15);
        } else {
          _minutes = 0;
        }
      } else {
        _minutes -= 15;
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (!_isLayover && _hours == 0 && _minutes == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid duration'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final detention = Detention(
        duration: Duration(hours: _hours, minutes: _minutes),
        approverName: _approverController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isLayover: _isLayover,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(detention);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AlertDialog(
      title: Text(
        'Record Waiting Time',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeColumn(
                    'Hours',
                    _hours,
                    _incrementHours,
                    _decrementHours,
                  ),
                  const SizedBox(width: 16),
                  Text(':', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 16),
                  _buildTimeColumn(
                    'Minutes',
                    _minutes,
                    _incrementMinutes,
                    _decrementMinutes,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Overnight Toggle
              SwitchListTile(
                value: _isLayover,
                onChanged: (val) => setState(() => _isLayover = val),
                title: Text(
                  'Overnight Stay',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Driver stayed overnight',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
                ),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: tokens.textPrimary,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _approverController,
                decoration: InputDecoration(
                  labelText: 'Approver Name (Required)',
                  hintText: 'e.g., Warehouse Manager',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Approver name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Reason for delay...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save Entry'),
        ),
      ],
    );
  }

  Widget _buildTimeColumn(
    String label,
    int value,
    VoidCallback onInc,
    VoidCallback onDec,
  ) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onInc,
          icon: const Icon(Icons.add),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onDec,
          icon: const Icon(Icons.remove),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
