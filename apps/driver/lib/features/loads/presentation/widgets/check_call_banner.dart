import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';
import 'package:gap/gap.dart';
import 'submit_check_call_sheet.dart';

class CheckCallBanner extends StatelessWidget {
  final CheckCall checkCall;
  final VoidCallback onSubmitted;

  const CheckCallBanner({
    required this.checkCall,
    required this.onSubmitted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    // Dynamic icon based on type
    IconData typeIcon;
    switch (checkCall.type) {
      case CheckCallType.location: typeIcon = Icons.location_searching; break;
      case CheckCallType.temperature: typeIcon = Icons.thermostat; break;
      case CheckCallType.weight: typeIcon = Icons.scale; break;
      case CheckCallType.eta: typeIcon = Icons.update; break;
      case CheckCallType.custom: typeIcon = Icons.help_outline; break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacingM),
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(tokens.shapeL),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: theme.colorScheme.primary, size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispatcher Request',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  checkCall.prompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          M3SpringButton(
            onTap: () => _showResponseSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(tokens.shapeFull),
              ),
              child: Text(
                'RESPOND',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResponseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubmitCheckCallSheet(
        checkCall: checkCall,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
