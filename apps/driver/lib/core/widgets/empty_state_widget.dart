import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacingL),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.primary),
            ),
            SizedBox(height: tokens.spacingM),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacingS),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.spacingL),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacingXL,
                    vertical: tokens.spacingM,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
