import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:gap/gap.dart';
import 'dart:ui';

class ShareConfirmationSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ShareConfirmationSheet({
    required this.data,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.shapeL)),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: tokens.glassBlur, sigmaY: tokens.glassBlur),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(24),

            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                const Gap(12),
                Text(
                  'Trip Details Detected',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(24),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: tokens.glassOpacity),
                borderRadius: BorderRadius.circular(tokens.shapeM),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: tokens.glassBorderOpacity),
                ),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Trip Number',
                    value: (data['tripNumber'] as String?) ?? 'Not specified',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Truck / Trailer',
                    value: '${(data['truckNumber'] as String?) ?? '-'} / ${(data['trailerNumber'] as String?) ?? '-'}',
                    icon: Icons.local_shipping_outlined,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Pickup',
                    value: (data['startLocation'] as String?)?.split(',').first ?? 'Not specified',
                    subValue: (data['date'] as String?) ?? 'No date detected',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
            const Gap(32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeL),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeL),
                      ),
                    ),
                    child: const Text('Confirm & Start Trip'),
                  ),
                ),
              ],
            ),
            Gap(MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subValue != null)
                Text(
                  subValue!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
